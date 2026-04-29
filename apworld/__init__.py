from worlds.AutoWorld import World, WebWorld
from worlds.LauncherComponents import Component, components, Type, SuffixIdentifier, launch
from BaseClasses import Region, Location, Item, ItemClassification
from Options import Toggle, PerGameCommonOptions, DeathLink
from dataclasses import dataclass
import math

def run_client(*args):
    from .client import launch as client_launch
    launch(client_launch, name="Winnie the Pooh's Home Run Derby Client", args=args)

components.append(Component(
    "Winnie the Pooh's Home Run Derby Client",
    func=run_client,
    component_type=Type.CLIENT,
    file_identifier=SuffixIdentifier(".swf"),
))

class ShuffleStages(Toggle):
    """
    When enabled, stages must be found as items in the multiworld.
    Stages are locked until their unlock item is received.

    To ensure the game is playable from the start, also configure
    the starting inventory to include at least one stage.

    For example: start_inventory: {Eeyore: 1}
    """
    display_name = "Shuffle Stages"

@dataclass
class WPHRDOptions(PerGameCommonOptions):
    shuffle_stages: ShuffleStages
    death_link: DeathLink

class WPHRDItem(Item):
    game = "Winnie the Pooh's Home Run Derby"

class WPHRDLocation(Location):
    game = "Winnie the Pooh's Home Run Derby"

STAGE_NAMES = [
    "Eeyore",
    "Lumpy",
    "Piglet",
    "Kanga & Roo",
    "Rabbit",
    "Owl",
    "Tigger",
    "Christopher Robin",
]

NUM_POWER_UPS = 20

ITEM_NAMES = [
    "Power Up",
    "Contact Up",
    "Speed Up",
]

NUM_REPEATIONS = math.ceil(NUM_POWER_UPS * len(ITEM_NAMES) / len(STAGE_NAMES[:-1]))
REPEATABLE_STAGES = [f"{name} ({i + 2})" for i in range(NUM_REPEATIONS) for name in STAGE_NAMES[:-1]]
LOCATIONS = {f"Beat {name}": i + 1 for i, name in enumerate(STAGE_NAMES + REPEATABLE_STAGES)}

ITEMS = {name: i + 1 for i, name in enumerate(STAGE_NAMES + ITEM_NAMES)}

class WPHRDWeb(WebWorld):
    theme = "ocean"

class WPHRDWorld(World):
    """Winnie the Pooh's Home Run Derby — beat all eight pitchers
    to win the game. Collect stat upgrades from the multiworld
    to power up Pooh's batting."""

    game = "Winnie the Pooh's Home Run Derby"
    web = WPHRDWeb()

    options_dataclass = WPHRDOptions
    options: WPHRDOptions

    item_name_to_id = ITEMS
    location_name_to_id = LOCATIONS

    def create_item(self, name: str) -> WPHRDItem:
        if name not in ITEM_NAMES:
            classification = ItemClassification.progression
        else:
            classification = ItemClassification.useful
        return WPHRDItem(name, classification, ITEMS[name], self.player)

    def create_item_pool(self) -> [WPHRDItem]:
        pool = []

        if self.options.shuffle_stages:
            for name in STAGE_NAMES:
                pool.append(self.create_item(name))

        for _ in range(NUM_POWER_UPS):
            for item in ITEM_NAMES:
                pool.append(self.create_item(item))

        return pool

    def create_items(self) -> None:
        self.multiworld.itempool += self.create_item_pool()

    def create_regions(self) -> None:
        menu = Region("Menu", self.player, self.multiworld)
        itempool = self.create_item_pool()
        for loc_name, loc_id in LOCATIONS.items():
            if (len(menu.locations) >= len(itempool)):
                break
            loc = WPHRDLocation(self.player, loc_name, loc_id, menu)
            menu.locations.append(loc)
        self.multiworld.regions.append(menu)

    def set_rules(self) -> None:
        stage_locations = list(LOCATIONS.keys())

        if self.options.shuffle_stages:
            for i, loc_name in enumerate(stage_locations):
                if i >= len(STAGE_NAMES):
                    real_id = (i - len(STAGE_NAMES)) % (len(STAGE_NAMES) - 1)
                    item_name = stage_locations[real_id].removeprefix("Beat ")
                else:
                    item_name = loc_name.removeprefix("Beat ")
                try:
                    self.multiworld.get_location(loc_name, self.player).access_rule = \
                        lambda state, n=item_name: state.has(n, self.player)
                except KeyError:
                    break
        else:
            # original sequential unlock rules
            self.multiworld.get_location(
                stage_locations[0], self.player
            ).access_rule = lambda state: True

            for i in range(1, len(STAGE_NAMES) - 1):
                self.multiworld.get_location(
                    stage_locations[i], self.player
                ).access_rule = lambda state, prev=stage_locations[i - 1]: \
                    state.can_reach(prev, "Location", self.player)

            for i in range(len(STAGE_NAMES), len(stage_locations)):
                real_id = (i - len(STAGE_NAMES)) % (len(STAGE_NAMES) - 1)
                if real_id == 0:
                    self.multiworld.get_location(
                        stage_locations[i], self.player
                    ).access_rule = lambda state: True
                else:
                    try:
                        self.multiworld.get_location(
                            stage_locations[i], self.player
                        ).access_rule = lambda state, prev=stage_locations[real_id - 1]: \
                            state.can_reach(prev, "Location", self.player)
                    except KeyError:
                        break

        self.multiworld.completion_condition[self.player] = \
            lambda state: state.can_reach(
                "Beat Christopher Robin", "Location", self.player
            )

    def fill_slot_data(self) -> dict:
        return self.options.as_dict("shuffle_stages", "death_link")
