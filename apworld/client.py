import asyncio
import subprocess
import os
import sys
import json
import bsdiff4
import hashlib
import tempfile
import copy

import Utils
from NetUtils import RawJSONtoTextParser
from CommonClient import CommonContext, server_loop, get_base_parser, logger, gui_enabled
from worlds import network_data_package
from importlib.resources import files

CLIENT_ID = "winnie_the_pooh_hrd"
GAME_HASH = "a083b6278f3ad7c7dc69559837144e1b27a5748078862fc28882eb61763f03b3"

location_name_to_id = network_data_package["games"]["Winnie the Pooh's Home Run Derby"]["location_name_to_id"]
location_id_to_name = {v: k for k, v in location_name_to_id.items()}

def get_game_path() -> str:
    """Ask the user for the game path if not already stored."""
    from Utils import persistent_load, persistent_store
    stored = persistent_load().get(CLIENT_ID, {}).get("game_path")
    if stored and os.path.exists(stored):
        return stored

    path = Utils.open_filename(
        title="Select the Game SWF",
        filetypes=(("Shockwave Flash files", "*.swf"), ("All files", "*.*"))
    )

    persistent_store(CLIENT_ID, "game_path", path)
    return path

def read_file(*path) -> bytes:
    try:
        from importlib.resources import files
        return files(__package__).joinpath(*path).read_bytes()
    except (AttributeError, TypeError):
        # fallback for plain directory installs
        file_path = os.path.join(os.path.dirname(__file__), *path)
        with open(file_path, "rb") as f:
            return f.read()

def apply_patch(tmpdir: str) -> str:
    """Patches the vanilla game and returns path to the patched game."""
    game_path = get_game_path()

    with open(game_path, "rb") as f:
        swf = f.read()

    if hashlib.sha256(swf).hexdigest() != GAME_HASH:
        raise ValueError("SHA256 mismatch — wrong version of the game?")

    patch = read_file("data", "patch.bsdiff4")
    patched_swf = bsdiff4.patch(swf, patch)

    out_path = os.path.join(tmpdir, "patched.swf")
    with open(out_path, "wb") as f:
        f.write(patched_swf)

    logger.info(f"Patched game written to {out_path}")
    return out_path

def get_ruffle_path() -> str:
    from Utils import persistent_load, persistent_store
    stored = persistent_load().get(CLIENT_ID, {}).get("ruffle_path")
    if stored and os.path.exists(stored):
        return stored

    path = Utils.open_filename(
        title="Select the Ruffle executable",
        filetypes=(("Executable", "*.exe"), ("All files", "*.*"))
    )

    persistent_store(CLIENT_ID, "ruffle_path", path)
    return path

def launch_ruffle(swf_path: str, port: int) -> subprocess.Popen:
    """Launch Ruffle with the patched game."""
    if sys.platform == "win32":
        kwargs = {}
        kwargs["creationflags"] = subprocess.CREATE_NO_WINDOW
        ruffle = get_ruffle_path()
        proc = subprocess.Popen([ruffle, "--socket-allow", f"localhost:{port}", f"-Pport={port}", swf_path], **kwargs)
    else:
        ruffle = os.environ.get("RUFFLE_PATH", "ruffle")
        proc = subprocess.Popen([ruffle, "--socket-allow", f"localhost:{port}", f"-Pport={port}", swf_path])
    logger.info(f"Launched Ruffle (pid {proc.pid})")
    return proc

class WPHRDContext(CommonContext):
    game = "Winnie the Pooh's Home Run Derby"
    items_handling = 0b111

    def __init__(self, server_address, password):
        super().__init__(server_address, password)
        self.raw_text_parser = RawJSONtoTextParser(self)
        self.ruffle_proc: subprocess.Popen | None = None
        self.swf_writer: asyncio.StreamWriter | None = None
        self.swf_connected: bool = False
        self.initial_sync_done: bool = False
        self.last_sent_item_index: int = 0
        self.slot_data: dict = None

    async def server_auth(self, password_requested):
        if password_requested and not self.password:
            await super().server_auth(password_requested)
        await self.get_username()
        await self.send_connect()

    def on_package(self, cmd: str, args: dict):
        if cmd == "Connected":
            self.slot_data = args.get("slot_data", {})
            asyncio.create_task(
                self.update_death_link(bool(self.slot_data.get("death_link", False)))
            )
            asyncio.create_task(self.sync_to_swf())
        elif cmd == "ReceivedItems":
            asyncio.create_task(self.sync_to_swf())

    def on_print_json(self, args: dict):
        text = self.raw_text_parser(copy.deepcopy(args["data"]))
        asyncio.create_task(self.push_to_swf("message", text=text))

    def on_deathlink(self, data: dict):
        super().on_deathlink(data)
        cause = data.get("cause", "Someone died")
        asyncio.create_task(
            self.push_to_swf("deathlink", cause=cause)
        )

    async def sync_to_swf(self):
        """Push full current state to the SWF. Safe to call multiple times."""
        if not self.swf_connected or not self.username or not self.slot_data:
            return

        if not self.initial_sync_done:
            await self.push_to_swf("connected", slot=self.username)

        pending = list(self.items_received)[self.last_sent_item_index:]
        for item in pending:
            item_name = self.item_names.lookup_in_game(item.item)
            player_name = self.player_names.get(item.player, "Unknown")
            await self.push_to_swf("item", name=item_name, player=player_name)
        self.last_sent_item_index = len(self.items_received)

        checked = list(self.checked_locations)
        if not self.slot_data.get("shuffle_stages") and not self.initial_sync_done:
            loc_name = location_id_to_name[1].removeprefix("Beat ")
            await self.push_to_swf("item", name=f"{loc_name}", player=self.username)
            for loc_id in checked:
                if loc_id < 8:
                    loc_name = location_id_to_name[loc_id + 1].removeprefix("Beat ")
                    await self.push_to_swf("item", name=loc_name, player=self.username)

        await self.push_to_swf("sync_locations", cleared=checked)
        self.initial_sync_done = True

    async def push_to_swf(self, msg_type: str, **kwargs):
        if not self.swf_connected or self.swf_writer is None:
            return
        payload = json.dumps({"type": msg_type, **kwargs}) + "\n"
        try:
            self.swf_writer.write(payload.encode())
            self.swf_writer.write(b"\0")
            await self.swf_writer.drain()
        except ConnectionResetError:
            self.swf_connected = False

    async def handle_swf_connection(self, reader, writer):
        self.swf_writer = writer
        self.swf_connected = True
        self.initial_sync_done = False
        self.last_sent_item_index = 0
        logger.info("Game connected!")
        await self.sync_to_swf()
        try:
            while True:
                data = await reader.readuntil(b"\0")
                msg = json.loads(data.rstrip(b"\0").decode())
                await self.handle_swf_message(msg)
        except (asyncio.IncompleteReadError, ConnectionResetError):
            pass
        finally:
            self.swf_connected = False
            self.initial_sync_done = False
            self.last_sent_item_index = 0
            logger.info("Game disconnected.")

    async def handle_swf_message(self, msg: dict):
        if msg.get("type") == "check":
            stage = msg["location"]
            loc_name = f"Beat {stage}"
            for loc_id in self.missing_locations:
                name = location_id_to_name[loc_id]
                if name.startswith(loc_name):
                    await self.send_msgs([{
                        "cmd": "LocationChecks",
                        "locations": [loc_id]
                    }])
                    self.missing_locations.discard(loc_id)
                    self.checked_locations.add(loc_id)
                    if loc_id < 8 and not self.slot_data.get("shuffle_stages"):
                        next_stage = location_id_to_name[loc_id + 1].removeprefix("Beat ")
                        await self.push_to_swf("item", name=next_stage, player=self.username)
                    break
        elif msg.get("type") == "death":
            if "DeathLink" in self.tags:
                await self.send_death(death_text=f"{self.username} struck out!")

async def watch_ruffle(proc: subprocess.Popen, tasks: list[asyncio.Task]):
    while proc.poll() is None:
        await asyncio.sleep(1)
    logger.info("Ruffle exited, shutting down.")
    for task in tasks:
        task.cancel()

async def main(args, tmpdir: str):
    ctx = WPHRDContext(args.connect, args.password)

    server = await asyncio.start_server(
        ctx.handle_swf_connection, "localhost", 0
    )
    port = server.sockets[0].getsockname()[1]
    logger.info(f"Game server listening on port {port}")

    ctx.ruffle_proc = launch_ruffle(apply_patch(tmpdir), port)
    ctx.auth = args.name

    tasks = [
        asyncio.create_task(server_loop(ctx)),
        asyncio.create_task(server.serve_forever()),
    ]

    if gui_enabled:
        from kvui import GameManager
        ctx.ui = GameManager(ctx)
        tasks.append(asyncio.create_task(ctx.ui.async_run(), name="UI"))

    tasks.append(asyncio.create_task(watch_ruffle(ctx.ruffle_proc, tasks)))

    try:
        await asyncio.gather(*tasks)
    except asyncio.CancelledError:
        pass
    finally:
        if ctx.ruffle_proc and ctx.ruffle_proc.poll() is None:
            ctx.ruffle_proc.terminate()
        await ctx.shutdown()

def launch(*args):
    with tempfile.TemporaryDirectory() as tmpdir:
        parser = get_base_parser(description="Winnie the Pooh's Home Run Derpy Archipelago Client")
        parser.add_argument("--name", default="", help="Name of the player")
        parsed = parser.parse_args(args)
        asyncio.run(main(parsed, tmpdir))

if __name__ == "__main__":
    import colorama
    colorama.init()
    Utils.init_logging("WPHRDClient")
    launch(*sys.argv[1:])
