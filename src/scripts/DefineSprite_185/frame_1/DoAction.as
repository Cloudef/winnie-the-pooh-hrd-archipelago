function setLvIcon()
{
   mcLvIcon0.gotoAndStop(_parent._parent.soLvPow + 1);
   mcLvIcon1.gotoAndStop(_parent._parent.soLvMeet + 1);
   mcLvIcon2.gotoAndStop(_parent._parent.soLvSp + 1);
   lvPoint0 = lvPointArray0[_parent._parent.soLvPow];
   lvPoint1 = lvPointArray1[_parent._parent.soLvMeet];
   lvPoint2 = lvPointArray2[_parent._parent.soLvSp];
   var _loc3_ = 0;
   while(_loc3_ < 3)
   {
      this["lvBtn" + _loc3_].enabled = false;
      this["lvBtn" + _loc3_]._alpha = 20;
      if(this["lvPoint" + _loc3_] == 0)
      {
         this["lvPoint" + _loc3_] = "━";
      }
      _loc3_ = _loc3_ + 1;
   }
}
function setLvUp(myBtn)
{
   _parent._parent.soPoint -= this["lvPoint" + myBtn];
   if(myBtn == 0)
   {
      _parent._parent.soLvPow = _parent._parent.soLvPow + 1;
   }
   else if(myBtn == 1)
   {
      _parent._parent.soLvMeet = _parent._parent.soLvMeet + 1;
   }
   else
   {
      _parent._parent.soLvSp = _parent._parent.soLvSp + 1;
   }
   this.gotoAndPlay("lvUp");
   _parent._parent.soDataSave();
   setLvIcon();
}
this.stop();
var lvPointArray0 = [500,1000,1500,2000,3000,5000,7000,10000,15000,20000,25000,30000,35000,40000,50000,60000,70000,80000,90000,100000,0];
var lvPointArray1 = [300,500,700,1000,1500,2000,3000,5000,10000,15000,20000,25000,30000,40000,50000,60000,70000,80000,90000,100000,0];
var lvPointArray2 = [100,200,400,600,800,1000,1500,2000,3000,5000,7000,10000,15000,20000,25000,30000,35000,40000,45000,50000,0];
var lvPoint0 = 0;
var lvPoint1 = 0;
var lvPoint2 = 0;
setLvIcon();
