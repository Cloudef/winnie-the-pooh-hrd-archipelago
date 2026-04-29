var mcNum = Number(this._name.substr(7));
if(!_parent._parent.UNLOCKED_STAGES[mcNum])
{
   this.gotoAndStop("stop");
}
else
{
   this.gotoAndPlay("start");
}
