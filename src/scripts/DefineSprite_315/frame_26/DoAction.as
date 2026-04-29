this.stop();
if(targetNum > 0)
{
   this.onEnterFrame = function()
   {
      if(homeRunNum < targetNum)
      {
         homeRunNum += 0.25;
         homeRunNumTxt = Math.floor(homeRunNum);
         if(homeRunNum == normNum)
         {
            this.gotoAndStop("clear");
         }
         if(homeRunNum == targetNum)
         {
            delete this.onEnterFrame;
            if(targetNum < normNum)
            {
               _parent._parent.gameLose();
               this.gotoAndPlay("lose");
            }
            else
            {
               _parent._parent.gameClear();
               this.gotoAndPlay("win");
            }
         }
      }
   };
}
else
{
   _parent._parent.gameLose();
   this.gotoAndPlay("lose");
}
