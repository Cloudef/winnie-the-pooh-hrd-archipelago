var cleared = _parent._parent.CLEARED_STAGES;
var num_cleared = 0;
for (var i = 0; i < cleared.length; i++) {
   if (cleared[i]) num_cleared++;
}
var stageTxt: String = num_cleared + " of " + cleared.length + " cleared!";
var myLengthMax = _parent._parent.soLengthMax;
var lengthMaxTxt = String(myLengthMax);
if(myLengthMax % 1 == 0)
{
   lengthMaxTxt += ".0";
}
var myLengthTotal = _parent._parent.soLengthTotal;
var lengthTotalTxt = String(myLengthTotal);
if(myLengthTotal % 1 == 0)
{
   lengthTotalTxt += ".0";
}
