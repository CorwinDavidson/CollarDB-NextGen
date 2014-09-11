/*--------------------------------------------------------------------------------**
**  File: CDB - rlvmain                                                           **
** ------------------------------------------------------------------------------ **
**  Version: 6.00.001                                                             **
** ------------------------------------------------------------------------------ **
** Licensed under the GPLv2, with the additional requirement that these scripts   **
** remain "full perms" in Second Life®.  See "CollarDB License" for details.      **
** ------------------------------------------------------------------------------ **
** ©2014 CollarDB and Individual Contributors                                     **
**--------------------------------------------------------------------------------*/

//new viewer checking method, as of 2.73
//on rez, restart script
//on script start, query db for rlvon setting
//on rlvon response, if rlvon=0 then just switch to checked state.  if rlvon=1 or rlvon=unset then open listener, do @versionnum, start 30 second timer
//on listen, we got version, so stop timer, close listen, turn on rlv flag, and switch to checked state
//on timer, we haven't heard from viewer yet.  Either user is not running RLV, or else they're logging in and viewer could not respond yet when we asked.
//so do @versionnum one more time, and wait another 30 seconds.
//on next timer, give up. User is not running RLV.  Stop timer, close listener, set rlv flag to FALSE, save to db, and switch to checked state.

/*-------------//
//  VARIABLES  //
//-------------*/

integer g_iReady = FALSE;

integer g_iRLVOn = FALSE;         //set to TRUE if DB says user has turned RLV features on
integer g_iViewerCheck = FALSE; //set to TRUE if viewer is has responded to @versionnum message
integer g_iRLVNotify = FALSE;     //if TRUE, ownersay on each RLV restriction
integer g_iListener;
float g_fVersionTimeOut = 60.0;
integer g_iVersionChan = 293847;
integer g_iRlvVersion;
integer g_iCheckCount;            //increment this each time we say @versionnum.  check it each time timer goes off in default state. give up if it's >= 2
integer g_iReturnMenu;
string g_sRLVString = "RestrainedLife viewer v1.20";

//"checked" state - HANDLING RLV SUBMENUS AND COMMANDS
//on start, request RLV submenus
//on rlv submenu response, add to list
//on main submenu "RLV", bring up this menu

string g_sParentMenu = "Main";
string g_sSubMenu = "RLV";

key kMenuID;
integer RELAY_CHANNEL = -1812221819;
integer g_iVerbose;

string TURNON = "*Turn On*";
string TURNOFF = "*Turn Off*";
string CLEAR = "*Clear All*";

integer g_iLastDetach; //unix time of the last detach: used for checking if the detached time was small enough for not triggering the ping mechanism

list g_lOwners;

list g_lSources=[];
list g_lRestrictions=[];
list g_lOldRestrictions;
list g_lOldSources;

list g_lBaked=[];

integer g_iSitListener;
key g_kSitter=NULL_KEY;
key g_kSitTarget=NULL_KEY;


integer CMD_ADDSRC = 11;
integer CMD_REMSRC = 12;

$import lib.MessageMap.lslm ();
$import lib.CommonVariables.lslm ();
$import lib.CommonFunctions.lslm ();

/*---------------//
//  FUNCTIONS    //
//---------------*/

CheckVersion(integer iSecond)
{
    if (g_iCheckCount && !iSecond) {
        return; //ongoing try
    }
    if (g_iVerbose)
    {
        Notify(g_kWearer, "Attempting to enable Restrained Love Viewer functions.  " + g_sRLVString+ " or higher is required for all features to work.", TRUE);
    }
    g_iListener = llListen(g_iVersionChan, "", g_kWearer, "");
    llSetTimerEvent(g_fVersionTimeOut);
    g_iCheckCount = !iSecond;
    llOwnerSay("@versionnum=" + (string)g_iVersionChan);
}

DoMenu(key kID)
{
    list lButtons;
    if (g_iRLVOn)
    {
        lButtons += [TURNOFF, CLEAR] + llListSort(g_lButtons, 1, TRUE);
    }
    else
    {
        lButtons += [TURNON];
    }

    string sPrompt = "Restrained Love Viewer Options.";
    if (g_iRlvVersion) 
    {
        sPrompt += "\nDetected version of RLV API: "+(string)g_iRlvVersion;
    }
    kMenuID = Dialog(kID, sPrompt, lButtons, [UPMENU], 0);
}

// Book keeping functions


SendCommand(string sCmd)
{
    llOwnerSay("@"+sCmd);
    if (g_iRLVNotify)
    {
        Notify(g_kWearer, "Sent RLV Command: " + sCmd, TRUE);
    }

}

HandleRLVCommand(key kID, string sCommand)
{
    string sStr=llToLower(sCommand);
    list lArgs = llParseString2List(sStr,["="],[]);
    string sCom = llList2String(lArgs,0);
    if (llGetSubString(sCom,-1,-1)==":")
    {
        sCom=llGetSubString(sCom,0,-2);
    }
    string sVal = llList2String(lArgs,1);
    
    if (sVal=="n"||sVal=="add") 
        AddRestriction(kID,sCom);
    else if (sVal=="y"||sVal=="rem") 
        RemRestriction(kID,sCom);
    else if (sCom=="clear") 
        Release(kID,sVal);
    else
    {
        SendCommand(sStr);
        if ((g_kSitter==NULL_KEY) && (llGetSubString(sStr,0,3)=="sit:"))
        {
            g_kSitter=kID;
            g_kSitTarget=(key)llGetSubString(sCom,4,-1);
        }
    }
}

AddRestriction(key kID, string sBehav)
{
    integer iSource=llListFindList(g_lSources,[kID]);
    integer iRestr;
    // lock the collar for the first coming relay restriction  (change the test if we decide that collar restrictions should un/lock)
    if ((kID != NULL_KEY) && (g_lSources == [] || g_lSources == [NULL_KEY]))
    {
        ApplyAdd("detach");
    }
    if (iSource==-1)
    {
        g_lSources+=[kID];
        g_lRestrictions+=[sBehav];
        iRestr=-1;
        if (kID!=NULL_KEY) llMessageLinked(LINK_SET, CMD_ADDSRC,"",kID);
    }
    else
    {
        list lSrcRestr = llParseString2List(llList2String(g_lRestrictions,iSource),["/"],[]);
        iRestr=llListFindList(lSrcRestr, [sBehav]);
        if (iRestr==-1)
        {
            g_lRestrictions=llListReplaceList(g_lRestrictions,[llDumpList2String(lSrcRestr+[sBehav],"/")],iSource, iSource);
        }
    }
    if (iRestr==-1)
    {
        ApplyAdd(sBehav);
        if (sBehav=="unsit")
        {
            g_kSitTarget = llList2Key(llGetObjectDetails(g_kWearer, [OBJECT_ROOT]),0);
            g_kSitter=kID;
        }
    }
}

ApplyAdd (string sBehav)
{
    integer iRestr=llListFindList(g_lBaked, [sBehav]);
    if (iRestr==-1)
    {
        //if (g_lBaked==[]) SendCommand("detach=n");  removed this as locking is owner privilege
        g_lBaked+=[sBehav];
        SendCommand(sBehav+"=n");
        //Debug(sBehav);
    }
}

RemRestriction(key kID, string sBehav)
{
    integer iSource=llListFindList(g_lSources,[kID]);
    integer iRestr;
    if (iSource!=-1)
    {
        list lSrcRestr = llParseString2List(llList2String(g_lRestrictions,iSource),["/"],[]);
        iRestr=llListFindList(lSrcRestr,[sBehav]);
        if (iRestr!=-1)
        {
            if (llGetListLength(lSrcRestr)==1)
            {
                g_lRestrictions=llDeleteSubList(g_lRestrictions,iSource, iSource);
                g_lSources=llDeleteSubList(g_lSources,iSource, iSource);
                if (kID!=NULL_KEY) llMessageLinked(LINK_SET, CMD_REMSRC,"",kID);
            }
            else
            {
                lSrcRestr=llDeleteSubList(lSrcRestr,iRestr,iRestr);
                g_lRestrictions=llListReplaceList(g_lRestrictions,[llDumpList2String(lSrcRestr,"/")] ,iSource,iSource);
            }
            if (sBehav=="unsit"&&g_kSitter==kID)
            {
                g_kSitter=NULL_KEY;
                g_kSitTarget=NULL_KEY;

            }
            ApplyRem(sBehav);
        }
    }
    // unlock the collar for the last going relay restriction (change the test if we decide that collar restrictions should un/lock)
    if (kID != NULL_KEY && (g_lSources == [] || g_lSources == [NULL_KEY])) ApplyRem("detach");
}

ApplyRem(string sBehav)
{
    integer iRestr=llListFindList(g_lBaked, [sBehav]);
    if (iRestr!=-1)
    {
        integer i;
        integer iFound=FALSE;
        for (i=0;i<=llGetListLength(g_lRestrictions);i++)
        {
            list lSrcRestr=llParseString2List(llList2String(g_lRestrictions,i),["/"],[]);
            if (llListFindList(lSrcRestr, [sBehav])!=-1) iFound=TRUE;
        }
        if (!iFound)
        {
            g_lBaked=llDeleteSubList(g_lBaked,iRestr,iRestr);
            //if (sBehav!="no_hax")  removed: issue 1040
            SendCommand(sBehav+"=y");
        }
    }
    //    if (g_lBaked==[]) SendCommand("detach=y");
}

Release(key kID, string sPattern)
{
    integer iSource=llListFindList(g_lSources,[kID]);
    if (iSource!=-1) {
        list lSrcRestr=llParseString2List(llList2String(g_lRestrictions,iSource),["/"],[]);
        integer i;
        if (sPattern!="") {
            for (i=0;i<=llGetListLength(lSrcRestr);i++) {
                string  sBehav=llList2String(lSrcRestr,i);
                if (llSubStringIndex(sBehav,sPattern)!=-1) {
                    RemRestriction(kID,sBehav);
                }
            }
        } else {
            g_lRestrictions=llDeleteSubList(g_lRestrictions,iSource, iSource);
            g_lSources=llDeleteSubList(g_lSources,iSource, iSource);
            llMessageLinked(LINK_SET, CMD_REMSRC,"",kID);
            for (i=0;i<=llGetListLength(lSrcRestr);i++) {
                string  sBehav=llList2String(lSrcRestr,i);
                ApplyRem(sBehav);
                if (sBehav=="unsit"&&g_kSitter==kID) {
                    g_kSitter=NULL_KEY;
                    g_kSitTarget=NULL_KEY;

                }
            }
            //should fix issue 927 (there was nothing to remove detach if the furniture did not explicitly set the restriction)
            if (g_lSources == [] || g_lSources == [NULL_KEY]) {
                ApplyRem("detach"); 
            }
        }
    }
}


SafeWord(integer iCollarToo) {
    SendCommand("clear");
    g_lBaked=[];
    g_lSources=[];
    g_lRestrictions=[];
    integer i;
    if (!iCollarToo) {
        llMessageLinked(LINK_SET,RLV_REFRESH,"",NULL_KEY);
    }
}


// End of book keeping functions


init()
{
    g_iReady = FALSE;
    g_kWearer = llGetOwner();
    //request setting from DB
    llSleep(1.0);
    llMessageLinked(LINK_SET, SETTING_REQUEST, "rlvon", NULL_KEY);

    // Ensure that menu script knows we're here.
    llMessageLinked(LINK_SET, MENU_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, NULL_KEY);
//#mdebug info
    Debug("Free Memory: " + (string)llGetFreeMemory());
//#enddebug
}

ready()
{
    g_iReady = TRUE;
    g_lButtons = [];    //clear this list now in case there are old entries in it
    //we only need to request submenus if rlv is turned on and running
    if (g_iRLVOn && g_iViewerCheck)
    {   //ask RLV plugins to tell us about their rlv submenus
        llMessageLinked(LINK_SET, MENU_REQUEST, g_sSubMenu, NULL_KEY);
        //tell rlv plugins to reinstate restrictions  (and wake up the relay listener... so that it can at least hear !pong's!
        llMessageLinked(LINK_SET, RLV_REFRESH, "", NULL_KEY);
        llSleep(5); //Make sure the relay is ready before pinging
        //ping inworld object so that they reinstate their restrictions
        
        g_lOldRestrictions=g_lRestrictions;
        g_lOldSources=g_lSources;
        g_lRestrictions=[];
        g_lSources=[];
        g_lBaked=[];
        
        integer i;
        for (i=0;i<llGetListLength(g_lOldSources);i++) {
            if ((key)llList2String(g_lOldSources,i)) {
                llShout(RELAY_CHANNEL,"ping,"+llList2String(g_lOldSources,i)+",ping,ping");
            }
        }
        g_lOldSources=[];
        g_lOldRestrictions=[];
    }
    // Ensure that menu script knows we're here.
    llMessageLinked(LINK_SET, MENU_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, NULL_KEY);
}
/*---------------//
//  HANDLERS     //
//---------------*/

HandleHTTPDB(integer iSender, integer iNum, string sStr, key kID)
{
    list lParams = llParseString2List(sStr, ["="], []);
    string sToken = llList2String(lParams, 0);
    string sValue = llList2String(lParams, 1);

    if (((iNum == SETTING_SAVE) || (iNum == SETTING_RESPONSE)) && (sToken == "owner"))
    {
        if (llStringLength(sValue) > 0)
        {
            g_lOwners = llParseString2List(sValue, [","], []);
//#mdebug info
            Debug("owners: " + sValue);
//#enddebug
        }
    }
    else if (iNum == SETTING_RESPONSE)
    {
        if (sStr == "rlvon=0")
        {//RLV is turned off in DB.  just switch to checked state without checking viewer
            ready();
            llMessageLinked(LINK_SET, RLV_OFF, "", NULL_KEY);

        }
        else if (sStr == "rlvon=1")
        {//DB says we were running RLV last time it looked.  do @versionnum to check.

            g_iRLVOn = TRUE;
            CheckVersion(FALSE);
        }
        else if (sStr == "rlvnotify=1")
        {
            g_iRLVNotify = TRUE;
        }
        else if (sStr == "rlvnotify=0")
        {
            g_iRLVNotify = FALSE;
        }
        else if (sStr == "rlvon=unset")
        {
            CheckVersion(FALSE);
        }
    }
    else if ((iNum == SETTING_EMPTY && sStr == "rlvon"))
    {
        CheckVersion(FALSE);
    }
}

HandleDIALOG(integer iSender, integer iNum, string sStr, key kID)
{
    if (iNum == DIALOG_RESPONSE)
{
        list lMenuParams = llParseString2List(sStr, ["|"], []);
        key kAv = (key)llList2String(lMenuParams, 0);
        string sMsg = llList2String(lMenuParams, 1);
        integer iPage = (integer)llList2String(lMenuParams, 2);
//#mdebug info        
        Debug(sStr);
        Debug(sMsg);
//#enddebug        
        if (kID == kMenuID)
        {
            if (sMsg == TURNON)
            {
                llMessageLinked(LINK_SET, COMMAND_NOAUTH, "rlvon", kAv);
            }
            else if (sMsg == TURNOFF)
            {
                g_iReturnMenu = TRUE;
                llMessageLinked(LINK_SET, COMMAND_NOAUTH, "rlvoff", kAv);
            }
            else if (sMsg == CLEAR)
            {
                llMessageLinked(LINK_SET, COMMAND_NOAUTH, "clear", kAv);
                DoMenu(kAv);
            }
            else if (sMsg == UPMENU)
            {
                llMessageLinked(LINK_SET,MENU_SUBMENU, g_sParentMenu, kAv);
            }
            else if (llListFindList(g_lButtons, [sMsg]) != -1 && g_iRLVOn)
            {
                llMessageLinked(LINK_SET,MENU_SUBMENU, sMsg, kAv);
            }
        }
    }
    else if (iNum == DIALOG_TIMEOUT)
    {
        if (kID == kMenuID)
        {
            g_iReturnMenu = FALSE;
        }
    }
}

HandleMENU(integer iSender, integer iNum, string sStr, key kID)
{
    if (iNum ==MENU_SUBMENU)
    {
        if (sStr == g_sSubMenu)
        {
            if(g_iReady)
            {
                DoMenu(kID);
            }
            else
            {
                Notify(kID, "Still querying for viewer version.  Please try again in a minute.", FALSE);
            }
        }
    }
    else if (iNum == MENU_REQUEST && sStr == g_sParentMenu)
    {
        llMessageLinked(LINK_SET, MENU_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, NULL_KEY);
    }
    if (g_iRLVOn && g_iViewerCheck)
    {    
        if (iNum == MENU_RESPONSE)
        {
            list lParts = llParseString2List(sStr, ["|"], []);
            if (llList2String(lParts, 0) == g_sSubMenu)
            {//someone wants to stick something in our menu
                string sButton = llList2String(lParts, 1);
                if (llListFindList(g_lButtons, [sButton]) == -1)
                {
                    g_lButtons = llListSort(g_lButtons + [sButton], 1, TRUE);
                }
            }
        }
        else if (iNum == MENU_REMOVE)
        {
            integer iIndex;
            list lParts = llParseString2List(sStr, ["|"], []);
            if (llList2String(lParts, 0) == g_sSubMenu)
            {//someone wants to stick something in our menu
                string sButton = llList2String(lParts, 1);
                iIndex = llListFindList(g_lButtons, [sButton]);
                if (iIndex != -1)
                {
                    g_lButtons = llDeleteSubList(g_lButtons, iIndex, iIndex);
                }
            }
        } 
    }
}

HandleCOMMAND(integer iSender, integer iNum, string sStr, key kID)
{
    if (iNum >= COMMAND_OWNER && iNum <= COMMAND_WEARER) { 
        if (llToUpper(sStr) == g_sSubMenu)
        {
            DoMenu(kID);
        }
        else if (sStr == "rlvon") {
            llMessageLinked(LINK_SET, SETTING_SAVE, "rlvon=1", NULL_KEY);
            g_iRLVOn = TRUE;
            g_iVerbose = TRUE;
            init();
        }
        else if (startswith(sStr, "rlvnotify"))
        {
            string sOnOff = llList2String(llParseString2List(sStr, [" "], []), 1);
            if (sOnOff == "on")
            {
                g_iRLVNotify = TRUE;
                llMessageLinked(LINK_SET, SETTING_SAVE, "rlvnotify=1", NULL_KEY);
            }
            else if (sOnOff == "off")
            {
                g_iRLVNotify = FALSE;
                llMessageLinked(LINK_SET, SETTING_SAVE, "rlvnotify=0", NULL_KEY);
            }
        }
        if (g_iRLVOn && g_iViewerCheck)
        {
//#mdebug info        	
            Debug("cmd: " + sStr);
//#enddebug            
            if (sStr == "clear")
            {
                if (iNum == COMMAND_WEARER)
                {
                    Notify(g_kWearer,"Sorry, but the sub cannot clear RLV settings.",TRUE);
                }
                else
                {
                    llMessageLinked(LINK_SET, RLV_CLEAR, "", NULL_KEY);
                    SafeWord(TRUE);
                }
            }
            else if (sStr == "rlvon")
            {
                llMessageLinked(LINK_SET, SETTING_SAVE, "rlvon=1", NULL_KEY);
                g_iRLVOn = TRUE;
                g_iVerbose = TRUE;
                init();
            }
            else if (sStr == "rlvoff")
            {
                if (iNum == COMMAND_OWNER)
                {
                    g_iRLVOn = FALSE;
                    llMessageLinked(LINK_SET, SETTING_SAVE, "rlvon=0", NULL_KEY);
                    SafeWord(TRUE);
                    llMessageLinked(LINK_SET, RLV_OFF, "", NULL_KEY);


                }
                else
                {
                    Notify(kID, "Sorry, only owner may disable Restrained Love functions", FALSE);
                }

                if (g_iReturnMenu)
                {
                    g_iReturnMenu = FALSE;
                    DoMenu(kID);
                }
            }
            else if (sStr=="showrestrictions")
            {
                string sOut="You are being restricted by the following object";
                if (llGetListLength(g_lSources)==2) sOut+=":";
                else sOut+="s:";
                integer i;
                for (i=0;i<llGetListLength(g_lSources);i++)
                    if (llList2String(g_lSources,i)!=NULL_KEY) sOut+="\n"+llKey2Name((key)llList2String(g_lSources,i))+" ("+llList2String(g_lSources,i)+"): "+llList2String(g_lRestrictions,i);
                else sOut+="\nThis collar: "+llList2String(g_lRestrictions,i);
                Notify(kID,sOut,FALSE);
            }        
        }
    }
    if (g_iRLVOn && g_iViewerCheck)
    {   
        if (iNum == COMMAND_SAFEWORD)
        {// safeWord used, clear rlv settings
            llMessageLinked(LINK_SET, RLV_CLEAR, "", NULL_KEY);
            SafeWord(TRUE);
        }
        else if (iNum==COMMAND_RELAY_SAFEWORD)
        {
            SafeWord(FALSE);
        }
    }
}

HandleRLV(integer iSender, integer iNum, string sStr, key kID)
{
    if (g_iRLVOn && g_iViewerCheck)
    {   
        if (iNum == RLV_CMD)
        {
            list sCommands=llParseString2List(sStr,[","],[]);
            integer i;
            for (i=0;i<llGetListLength(sCommands);i++)
            {
                HandleRLVCommand(NULL_KEY,llList2String(sCommands,i));
            }
        }
        else if (iNum == RLV_CMD||iNum == RLVR_CMD)
        {
            HandleRLVCommand(kID,sStr);
        }
        else if (iNum == COMMAND_RLV_RELAY)
        {
            if (llGetSubString(sStr,-43,-1)!=","+(string)g_kWearer+",!pong") 
                return;
                
            if (kID==g_kSitter)
            {
                SendCommand("sit:"+(string)g_kSitTarget+"=force");
            }
            
            integer iSourceNum=llListFindList(g_lOldSources, [kID]);
            if (iSourceNum == -1) 
                return; // Unknown source decided to answer to this ping while uninvited. Better ignore it.
            
            integer j;
            list iRestr=llParseString2List(llList2String(g_lOldRestrictions,iSourceNum),["/"],[]);
            for (j=0;j<llGetListLength(iRestr);j++) 
                AddRestriction(kID,llList2String(iRestr,j));
        }
    }
}

/*---------------//
//  MAIN CODE    //
//---------------*/
default{
    state_entry() {
        init();
    }

    link_message(integer iSender, integer iNum, string sStr, key kID)
    {
        if ((iNum >= SETTING_SAVE) && (iNum <= SETTING_REQUEST_NOCACHE))
        {
            HandleHTTPDB(iSender,iNum,sStr,kID);
        }
        else if ((iNum >= MENU_REQUEST) && (iNum <= MENU_REMOVE))
        {
            HandleMENU(iSender,iNum,sStr,kID); 
        }
        if(g_iReady)
        {
            if ((iNum >= RLV_REFRESH) && (iNum <= RLVR_CMD))
            {
                HandleRLV(iSender,iNum,sStr,kID);
            }
            else if ((iNum >= DIALOG_TIMEOUT) && (iNum <= DIALOG_REQUEST))
            {
                HandleDIALOG(iSender,iNum,sStr,kID);
            }        
            else if ((iNum >= COMMAND_OWNER) && (iNum <= COMMAND_WEARERLOCKEDOUT))
            {
                HandleCOMMAND(iSender,iNum,sStr,kID);
            }
        }
    } 
    
    listen(integer iChan, string sName, key kID, string sMsg)
    {
        if (iChan == g_iVersionChan)
        {
            llListenRemove(g_iListener);
            llSetTimerEvent(0.0);
            g_iCheckCount = 0;

            g_iRlvVersion = (integer)llGetSubString(sMsg, 0, 2);
            llMessageLinked(LINK_SET, RLV_VERSION, (string)g_iRlvVersion, NULL_KEY);
            
            g_iRLVOn = TRUE;

            if (g_iRLVNotify)
            {
                llOwnerSay("Restrained Love functions enabled. " + sMsg + " detected.");    //turned off for issue 896
            }
            g_iViewerCheck = TRUE;

            llMessageLinked(LINK_SET, RLV_ON, "", NULL_KEY);

            ready();
        }
    }

    timer() {
        llListenRemove(g_iListener);
        llSetTimerEvent(0.0);
        if (g_iCheckCount) {   
            CheckVersion(TRUE);
        }
        else {   
            //we've given the viewer a full 60 seconds
            g_iViewerCheck = FALSE;
            g_iRLVOn = FALSE;
            llMessageLinked(LINK_SET, RLV_OFF, "", NULL_KEY);

            Notify(g_kWearer,"Could not detect Restrained Love Viewer.  Restrained Love functions disabled.",TRUE);
            
            if (llGetListLength(g_lRestrictions) > 0 && llGetListLength(g_lOwners) > 0) {
                string sMsg = llKey2Name(g_kWearer)+" appears to have logged in without using the Restrained Love Viewer.  Their Restrained Love functions have been disabled.";
                if (llGetListLength(g_lOwners) == 2) {
                    // only 1 owner
                    Notify(g_kWearer,"Your owner has been notified.",FALSE);
                    Notify(llList2Key(g_lOwners,0), sMsg, FALSE);
                } 
                else 
                {
                    Notify(g_kWearer,"Your owners have been notified.",FALSE);
                    integer i;
                    for(i=0; i < llGetListLength(g_lOwners); i+=2) 
                    {
                        Notify(llList2Key(g_lOwners,i), sMsg, FALSE);
                    }
                }
            }
            ready();
        }
    }
      
    attach(key kID)
    {
        if (kID == NULL_KEY) 
            g_iLastDetach = llGetUnixTime(); //remember when the collar was detached last
    }
    
    on_rez(integer iParam) {
        //reset only if the detach delay was long enough (it could be an
        //automatic reattach)
        if (llGetUnixTime()-g_iLastDetach > 15) 
        {
            init();
        } 
        else 
        {
            integer i;
            for (i = 0; i < llGetListLength(g_lBaked); i++)
            {
                SendCommand(llList2String(g_lBaked,i)+"=n");
            }
            llSleep(2);
            llMessageLinked(LINK_SET, RLV_REFRESH, "", NULL_KEY);         
        }
    }
    
    changed(integer change) {
        if (change & CHANGED_OWNER) {
            llResetScript();
        }
    }
}