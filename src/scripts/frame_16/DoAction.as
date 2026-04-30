class JSON {
	static function parse(text: String) {
        var at = 0;
        var ch = ' ';
		var _value: Function;
        var _error: Function = function (m) {
            throw {
                name: 'JSONError',
                message: m,
                at: at - 1,
                text: text
            };
        }

        var _next: Function = function() {
            ch = text.charAt(at);
            at += 1;
            return ch;
        }

        var _white: Function = function() {
            while (ch) {
                if (ch <= ' ') {
                    _next();
                } else if (ch == '/') {
                    switch (_next()) {
                        case '/':
                            while (_next() && ch != '\n' && ch != '\r') {}
                            break;
                        case '*':
                            _next();
                            for (;;) {
                                if (ch) {
                                    if (ch == '*') {
                                        if (_next() == '/') {
                                            _next();
                                            break;
                                        }
                                    } else {
                                        _next();
                                    }
                                } else {
                                    _error("Unterminated comment");
                                }
                            }
                            break;
                        default:
                            _error("Syntax error");
                    }
                } else {
                    break;
                }
            }
        }

        var _string: Function = function() {
            var i;
            var s = '';
            var t;
            var u;
			var outer: Boolean = false;
            if (ch == '"') {
				while (_next()) {
                    if (ch == '"') {
                        _next();
                        return s;
                    } else if (ch == '\\') {
                        switch (_next()) {
                        case 'b':
                            s += '\b';
                            break;
                        case 'f':
                            s += '\f';
                            break;
                        case 'n':
                            s += '\n';
                            break;
                        case 'r':
                            s += '\r';
                            break;
                        case 't':
                            s += '\t';
                            break;
                        case 'u':
                            u = 0;
                            for (i = 0; i < 4; i += 1) {
                                t = parseInt(_next(), 16);
                                if (!isFinite(t)) {
                                    outer = true;
									break;
                                }
                                u = u * 16 + t;
                            }
							if(outer) {
								outer = false;
								break;
							}
                            s += String.fromCharCode(u);
                            break;
                        default:
                            s += ch;
                        }
                    } else {
                        s += ch;
                    }
                }
            }
            _error("Bad string");
        }

        var _array: Function = function() {
            var a = [];
            if (ch == '[') {
                _next();
                _white();
                if (ch == ']') {
                    _next();
                    return a;
                }
                while (ch) {
                    a.push(_value());
                    _white();
                    if (ch == ']') {
                        _next();
                        return a;
                    } else if (ch != ',') {
                        break;
                    }
                    _next();
                    _white();
                }
            }
            _error("Bad array");
        }

        var _object: Function = function() {
            var k;
            var o = {};
            if (ch == '{') {
                _next();
                _white();
                if (ch == '}') {
                    _next();
                    return o;
                }
                while (ch) {
                    k = _string();
                    _white();
                    if (ch != ':') {
                        break;
                    }
                    _next();
                    o[k] = _value();
                    _white();
                    if (ch == '}') {
                        _next();
                        return o;
                    } else if (ch != ',') {
                        break;
                    }
                    _next();
                    _white();
                }
            }
            _error("Bad object");
        }

        var _number: Function = function() {
            var n = '';
            var v;
            if (ch == '-') {
                n = '-';
                _next();
            }
            while (ch >= '0' && ch <= '9') {
                n += ch;
                _next();
            }
            if (ch == '.') {
                n += '.';
                while (_next() && ch >= '0' && ch <= '9') {
                    n += ch;
                }
            }
            //v = +n;
			v = 1 * n;
            if (!isFinite(v)) {
                _error("Bad number");
            } else {
                return v;
            }
        }

        var _word: Function = function() {
            switch (ch) {
                case 't':
                    if (_next() == 'r' && _next() == 'u' && _next() == 'e') {
                        _next();
                        return true;
                    }
                    break;
                case 'f':
                    if (_next() == 'a' && _next() == 'l' && _next() == 's' &&
                            _next() == 'e') {
                        _next();
                        return false;
                    }
                    break;
                case 'n':
                    if (_next() == 'u' && _next() == 'l' && _next() == 'l') {
                        _next();
                        return null;
                    }
                    break;
            }
            _error("Syntax error");
        }

        _value = function() {
            _white();
            switch (ch) {
                case '{':
                    return _object();
                case '[':
                    return _array();
                case '"':
                    return _string();
                case '-':
                    return _number();
                default:
                    return ch >= '0' && ch <= '9' ? _number() : _word();
            }
        }
        return _value();
    }
}

var GAME_STAGES: Array = [
   "Eeyore",
   "Lumpy",
   "Piglet",
   "Kanga & Roo",
   "Rabbit",
   "Owl",
   "Tigger",
   "Christopher Robin"
];

var CLEARED_STAGES: Array = [
   false,
   false,
   false,
   false,
   false,
   false,
   false,
   false
];

var UNLOCKED_STAGES: Array = [
   false,
   false,
   false,
   false,
   false,
   false,
   false,
   false
];

function apInit()
{
   var overlay: MovieClip = _root.createEmptyMovieClip(
      "apOverlay", _root.getNextHighestDepth()
   );

   overlay.createTextField("messages", 1, 10, 400, 500, 80);
   var tf: TextField = overlay.messages;

   var fmt: TextFormat = new TextFormat();
   fmt.font = "_sans";
   fmt.size = 16;
   fmt.color = 0xFFFFFF;
   fmt.bold = true;
   tf.setNewTextFormat(fmt);
   tf.selectable = false;
   tf.multiline = true;
   tf.wordWrap = true;
   tf.filters = [new flash.filters.DropShadowFilter(2, 45, 0x000000, 1, 2, 2)];

   overlay.messageQueue = [];
   overlay.displayTimer = 0;
   overlay.DISPLAY_FRAMES = 60 * 3;
   overlay.syncing = false;

   overlay.onEnterFrame = function() {
      if (this.displayTimer > 0) {
         this.displayTimer--;
      } else if (this.messageQueue.length > 0) {
         this.messageQueue.shift();
         apUpdateMessages();
      }
   };

   var AP_PORT: Number = _root.port;
   overlay.socket = new XMLSocket();
   overlay.connected = false;
   overlay.connectTimer = setInterval(function() {
      overlay.socket.connect("localhost", AP_PORT);
   }, 1000);

   overlay.socket.onConnect = function(success: Boolean) {
      overlay.connected = success;
      if (success) {
         clearInterval(overlay.connectTimer);
      }
   };

   overlay.socket.onClose = function() {
      overlay.connected = false;
      overlay.connectTimer = setInterval(function() {
         overlay.socket.connect("localhost", AP_PORT);
      }, 1000);
   };

   overlay.socket.onData = function(rawData: String) {
       var lines: Array = rawData.split("\n");
       for (var i: Number = 0; i < lines.length; i++) {
           var line: String = lines[i];
           if (line.length == 0) continue;
           var msg: Object = JSON.parse(line);
           apHandlePacket(msg);
       }
   };
}

function apUpdateMessages()
{
   var overlay: MovieClip = _root.apOverlay;
   if (overlay.messageQueue.length == 0) {
      overlay.messages._alpha = 0;
      return;
   }
   while (overlay.messageQueue.length > 4) {
      overlay.messageQueue.shift();
   }
   overlay.messages.text = overlay.messageQueue.join('\n');
   overlay.messages._alpha = 100;
   overlay.displayTimer = overlay.DISPLAY_FRAMES;
}

function apShowMessage(text: String)
{
   var overlay: MovieClip = _root.apOverlay;
   overlay.messageQueue.push(text);
   apUpdateMessages();
}

function apHandlePacket(msg: Object) {
   var overlay: MovieClip = _root.apOverlay;
   if (msg.type == "connected") {
      overlay.syncing = true;
      for (var i: Number = 0; i < CLEARED_STAGES.length; i++) {
		CLEARED_STAGES[i] = false;
		UNLOCKED_STAGES[i] = false;
	  }
	  soLvPow = 0;
	  soLvMeet = 0;
	  soLvSp = 0;
      apShowMessage("Connected to Achipelago as " + msg.slot);
   } else if (msg.type == "sync_locations") {
      for (var i: Number = 0; i < msg.cleared.length; i++) {
         var id = msg.cleared[i] - 1;
         if (id >= 0 && id < CLEARED_STAGES.length) {
            CLEARED_STAGES[id] = true;
            trace("Synced location " + GAME_STAGES[id]);
         }
      }
      overlay.syncing = false;
   } else if (msg.type == "item") {
      trace("Received " + msg.name + " from " + msg.player + "!");
      if (msg.name == "Power Up") {
         soLvPow++;
      } else if (msg.name == "Contact Up") {
         soLvMeet++;
      } else if (msg.name == "Speed Up") {
         soLvSp++;
      } else {
         for (var i: Number = 0; i < GAME_STAGES.length; i++) {
            if (msg.name == GAME_STAGES[i]) {
               UNLOCKED_STAGES[i] = true;
            }
         }
      }
   } else if (msg.type == "message") {
	  trace("msg: " + msg.text);
      apShowMessage(msg.text);
   } else if (msg.type == "deathlink") {
	  trace("deathlink: " + msg.cause);
      apShowMessage(msg.cause);
      isDeathLink = true;
      gameLeft = 0;
      gameHomerun = 0;
      gameCombo = 0;
    }
}

function apSendCheck(locationName: String) {
   var overlay: MovieClip = _root.apOverlay;
   if (!overlay.connected) return;
   var msg: String = "{\"type\": \"check\", \"location\": \"" + locationName + "\"}";
   overlay.socket.send(msg);
}

function apSendDeathLink() {
   var overlay: MovieClip = _root.apOverlay;
   if (!overlay.connected) return;
   var msg: String = "{\"type\": \"death\"}";
   overlay.socket.send(msg);
}

apInit();

function setResult(myResult, myLength)
{
   trace(myResult + " " + myLength);
   mcResult._visible = true;
   mcResult.gotoAndPlay(myResult);
   if(myResult == "homeRun")
   {
      gameHomeRun++;
      gameLength = Math.floor(myLength * 0.1) * 0.1;
      gameLengthTotal += gameLength;
      if(gameLength > gameLengthMax)
      {
         gameLengthMax = gameLength;
      }
      gameCombo++;
      if(gameCombo > gameComboMax)
      {
         gameComboMax = gameCombo;
      }
   }
   else
   {
      gameCombo = 0;
   }
}
function setInfo(myStrike, myOut, myBase, myScore, myNorm, myInning)
{
   mcInfoCount.setCount(myStrike,myOut);
   mcInfoBase.setBase(myBase);
   mcInfoScore.setScore(myScore,myNorm,myInning);
}
function setTitle(myTitle)
{
   mcTitle.gotoAndPlay(myTitle);
}
function setBall()
{
   gameLeft--;
}
function gameStart(myStage)
{
   gameStage = myStage;
   gameNorm = GAME_NORM_ARRAY[myStage];
   gameBall = GAME_BALL_ARRAY[myStage];
   gameLeft = gameBall;
   gameHomeRun = 0;
   gameCombo = 0;
   gameComboMax = 0;
   gameLength = 0;
   gameLengthMax = 0;
   gameLengthTotal = 0;
   gameClearNum = false;
   isDeathLink = false;
   trace("▼ステージ[ " + myStage + " ]を開始します。");
   trace("球数 = " + gameBall + " ： ノルマ = " + gameBall);
   this.gotoAndStop("game");
   mcMain.mcMain.init();
}
function gameEnd()
{
   mcResult.gotoAndPlay("gameEnd");
   soLengthTotal += gameLengthTotal;
   trace(soHomeRunTotal);
   soHomeRunTotal += gameHomeRun;
   trace(soHomeRunTotal);
   soLengthMax = Math.max(soLengthMax,gameLengthMax);
   soHomeRunCombo = Math.max(soHomeRunCombo,gameComboMax);
}
function gameLose()
{
   trace("gameLose(" + isDeathLink + ")");
   if (!isDeathLink) {
      apSendDeathLink();
   }
}
function gameClear()
{
   trace("gameClear(): " + gameBall + " : " + gameHomeRun + " : " + gameNorm);
   CLEARED_STAGES[gameStage] = true;
   if (gameHomeRun == gameBall) {
      for (var i = 0; i < 10; i++) {
         apSendCheck(GAME_STAGES[gameStage]);
      }
   } else if (gameHomeRun >= gameNorm * 2) {
      for (var i = 0; i < 3; i++) {
         apSendCheck(GAME_STAGES[gameStage]);
      }
   } else {
      apSendCheck(GAME_STAGES[gameStage]);
   }
   gameClearNum = true;
}
function setPoint(myPoint) {}
var soundObj = new Sound();
var GAME_NORM_ARRAY = [3,5,8,12,15,19,28,40];
var GAME_BALL_ARRAY = [10,15,20,25,30,35,40,50];
var gameStage;
var gameBall;
var gameLeft;
var gameHomeRun;
var gameNorm;
var gameCombo;
var gameComboMax;
var gameLength;
var gameLengthMax;
var gameLengthTotal;
var gameClearNum = false;
var isDeathLink = false;
var soHomeRunTotal = 0;
var soHomeRunCombo = 0;
var soLengthMax = 0;
var soLengthTotal = 0;
var soPoint = 0;
var soLvPow = 0;
var soLvMeet = 0;
var soLvSp = 0;
this.stop();
