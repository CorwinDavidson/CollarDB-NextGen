/*--------------------------------------------------------------------------------**
**  File: CDB - bell                                                              **
** ------------------------------------------------------------------------------ **
**  Version: 6.00.001                                                             **
** ------------------------------------------------------------------------------ **
** Licensed under the GPLv2, with the additional requirement that these scripts   **
** remain "full perms" in Second Life®.  See "CollarDB License" for details.      **
** ------------------------------------------------------------------------------ **
** ©2014 CollarDB and Individual Contributors                                     **
**--------------------------------------------------------------------------------*/

/*-------------//
//  VARIABLES  //
//-------------*/

string g_sSubMenu = "Bell";
string g_sParentMenu = "AddOns";

list g_lLocalButtons = ["Vol +","Vol -","Delay +","Delay -","Next Sound","~Chat Help","Ring It"];

float g_fVolume=0.5; // volume of the bell
float g_fVolumeStep=0.1; // stepping for volume

float g_fSpeed=1.0; // Speed of the bell
float g_fSpeedStep=0.5; // stepping for Speed adjusting
float g_fSpeedMin=0.5; // stepping for Speed adjusting
float g_fSpeedMax=5.0; // stepping for Speed adjusting

string g_sSubPrefix;

integer g_iBellOn=0; // are we ringing. Off is 0, On = Auth of person which enabled
string g_sBellOn="*Bell On*"; // menu text of bell on
string g_sBellOff="*Bell Off*"; // menu text of bell on
integer g_iBellAvailable=FALSE;

integer g_iBellShow=TRUE; // is the bell visible
string g_sBellShow="Bell Show"; //menu text of bell visible
string g_sBellHide="Bell Hide"; //menu text of bell hidden

list g_listBellSounds=["7b04c2ee-90d9-99b8-fd70-8e212a72f90d","b442e334-cb8a-c30e-bcd0-5923f2cb175a","1acaf624-1d91-a5d5-5eca-17a44945f8b0","5ef4a0e7-345f-d9d1-ae7f-70b316e73742","da186b64-db0a-bba6-8852-75805cb10008","d4110266-f923-596f-5885-aaf4d73ec8c0","5c6dd6bc-1675-c57e-0847-5144e5611ef9","1dc1e689-3fd8-13c5-b57f-3fedd06b827a"]; // list with bell sounds
key g_kCurrentBellSound ; // curent bell sound key
integer g_iCurrentBellSound; // curent bell sound sumber
integer g_iBellSoundCount; // number of avail bell sounds
string g_sBellSoundIdentifier="bell_"; // use this to find additional sounds in the inventory


string g_sBellSaveToken="bell"; // token to save settings of the bell on the http
string g_sBellPrimName="Bell"; // Description for Bell elements

list g_lBellElements; // list with number of prims related to the bell

float g_fNextRing; // store time for the next ringing here;

string g_sBellChatPrefix="bell"; // prefix for chat commands

integer g_iHasControl=FALSE; // do we have control over the keyboard?

integer g_iLocalMenuCall=FALSE;

$import lib.MessageMap.lslm ();
$import lib.CommonVariables.lslm ();
$import lib.CommonFunctions.lslm ();


/*---------------//
//  FUNCTIONS    //
//---------------*/


DoMenu(key kID)
{
    string sPrompt = "Pick an option.\n";
    // sPrompt += "(Menu will time out in " + (string)g_iTimeOut + " seconds.)\n";
    list lMyButtons = g_lLocalButtons + g_lButtons;

    if (g_iBellOn>0) // the bell rings currently
    {
        lMyButtons+= g_sBellOff;
        sPrompt += "Bell is ringing";
    }
    else
    {
        lMyButtons+= g_sBellOn;
        sPrompt += "Bell is NOT ringing";
    }

    // Show button for showing/hiding the bell and add a text for it, if there is a bell
    if (g_iBellAvailable)
    {
        if (g_iBellShow) // the bell is hidden
        {
            lMyButtons+= g_sBellHide;
            sPrompt += " and shown.\n";
        }
        else
        {
            lMyButtons+= g_sBellShow;
            sPrompt += " and NOT shown.\n";
        }
    }
    else
    {  // no bell, so no text or sound
        sPrompt += ".\n";
    }

    // and show the volume and timing of the bell sound
    sPrompt += "The volume of the bell is now: "+(string)((integer)(g_fVolume*10))+"/10.\n";
    sPrompt += "The bell rings every "+llGetSubString((string)g_fSpeed,0,2)+" seconds when moving.\n";
    sPrompt += "Currently used sound: "+(string)(g_iCurrentBellSound+1)+"/"+(string)g_iBellSoundCount+"\n";

    lMyButtons = llListSort(lMyButtons, 1, TRUE);

    g_kDialogID=Dialog(kID, sPrompt, lMyButtons, [UPMENU], 0);
}


SetBellElementAlpha(float fAlpha)
{
    //loop through stored links, setting alpha if element type is bell
    integer n;
    integer iLinkElements = llGetListLength(g_lBellElements);
    for (n = 0; n < iLinkElements; n++)
    {
        llSetLinkAlpha(llList2Integer(g_lBellElements,n), fAlpha, ALL_SIDES);
    }
}

BuildBellElementList()
{
    integer n;
    integer iLinkCount = llGetNumberOfPrims();
    list lParams;

    // clear list just in case
    g_lBellElements = [];

    //root prim is 1, so start at 2
    for (n = 2; n <= iLinkCount; n++)
    {
        lParams=llParseString2List((string)llGetObjectDetails(llGetLinkKey(n), [OBJECT_DESC]), ["~"], []);
        if (llList2String(lParams, 0)==g_sBellPrimName)
        {
           g_lBellElements += [n];
        }
    }
    if (llGetListLength(g_lBellElements)>0)
    {
        g_iBellAvailable=TRUE;
    }
    else
    {
        g_iBellAvailable=FALSE;
    }

}

PrepareSounds()
{
    // parse names of sounds in inventiory if those are for the bell
    integer i;
    integer m=llGetInventoryNumber(INVENTORY_SOUND);
    string s;
    for (i=0;i<m;i++)
    {
        s=llGetInventoryName(INVENTORY_SOUND,i);
        if (startswith(s,g_sBellSoundIdentifier))
        {
            g_listBellSounds+=llGetInventoryKey(s);
        }
    }
    g_iBellSoundCount=llGetListLength(g_listBellSounds);
    g_iCurrentBellSound=0;
    g_kCurrentBellSound=llList2Key(g_listBellSounds,g_iCurrentBellSound);
}

ShowHelp(key kID)
{

    string sPrompt = "Help for bell chat command:\n";
    sPrompt += "All commands for the bell of the collar of "+llKey2Name(g_kWearer)+" start with \""+g_sSubPrefix+g_sBellChatPrefix+"\" followed by the command and the value, if needed.\n";
    sPrompt += "Examples: \""+g_sSubPrefix+g_sBellChatPrefix+" show\" or \""+g_sSubPrefix+g_sBellChatPrefix+" volume 10\"\n\n";
    sPrompt += "Commands:\n";
    sPrompt += "on: Enable bell sound.\n";
    sPrompt += "off: Disable bell sound.\n";
    sPrompt += "show: Show prims of bell.\n";
    sPrompt += "hide: Hide prims of bell.\n";
    sPrompt += "volume X: Set the volume for the bell, X=1-10\n";
    sPrompt += "delay X.X: Set the delay between rings, X=0.5-5.0\n";
    sPrompt += "help or ?: Show this help text.\n";

    Notify(kID,sPrompt,TRUE);

}

RestoreBellSettings(string sSettings)
{
    list lstSettings=llParseString2List(sSettings,[","],[]);

    // should the bell ring
    g_iBellOn=(integer)llList2String(lstSettings,0);
    if (g_iBellOn & !g_iHasControl)
    {
        llRequestPermissions(g_kWearer,PERMISSION_TAKE_CONTROLS);
    }
    else if (!g_iBellOn & g_iHasControl)
    {
        llReleaseControls();
        g_iHasControl=FALSE;

    }

    // is the bell visible?
    g_iBellShow=(integer)llList2String(lstSettings,1);
    if (g_iBellShow)
    {// make sure it can be seen
        SetBellElementAlpha(1.0);
    }
    else
    {// or is hidden
        SetBellElementAlpha(0.0);
    }

    // the number of the sound for ringing
    g_iCurrentBellSound=(integer)llList2String(lstSettings,2);
    g_kCurrentBellSound=llList2Key(g_listBellSounds,g_iCurrentBellSound);

    // bell volume
    g_fVolume=((float)llList2String(lstSettings,3))/10;

    // ring speed
    g_fSpeed=((float)llList2String(lstSettings,4))/10;
}

SaveBellSettings()
{
    string sSettings=g_sBellSaveToken+"=";
    // should the bell ring
    sSettings += (string)g_iBellOn+",";
    // is the bell visible?
    sSettings+=(string)g_iBellShow+",";
    // the number of the sound for ringing
    sSettings+=(string)g_iCurrentBellSound+",";
    // bell volume
    sSettings+=(string)llFloor(g_fVolume*10)+",";
    // ring speed
    sSettings+=(string)llFloor(g_fSpeed*10);

    llMessageLinked(LINK_SET, SETTING_SAVE,sSettings,NULL_KEY);
}

/*---------------//
//  HANDLERS     //
//---------------*/

// pragma inline
HandleHTTPDB(integer iSender, integer iNum, string sStr, key kID)
{
    if (iNum == SETTING_RESPONSE)
    {
        // some responses from the DB are coming in, check if it is about bell values
        list lParams = llParseString2List(sStr, ["="], []);
        string sToken = llList2String(lParams, 0);
        string sValue = llList2String(lParams, 1);

        if (sToken == g_sBellSaveToken )
        {
            RestoreBellSettings(sValue);
        }
        else if (sToken == "prefix")
        {
            g_sSubPrefix=sValue;
        }
    }
}

// pragma inline
HandleMENU(integer iSender, integer iNum, string sStr, key kID)
{
    if (iNum == MENU_SUBMENU)
    {
        if (sStr == g_sSubMenu)
        {
            DoMenu(kID);
        }
    }
    else if (iNum == MENU_REQUEST && sStr == g_sParentMenu)
    {
        llMessageLinked(LINK_SET, MENU_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, NULL_KEY);
    }
    else if (iNum == MENU_RESPONSE)
    {
        list lParts = llParseString2List(sStr, ["|"], []);
        if (llList2String(lParts, 0) == g_sSubMenu)
        {//someone wants to stick something in our menu
            string button = llList2String(lParts, 1);
            if (llListFindList(g_lButtons, [button]) == -1)
            {
                g_lButtons = llListSort(g_lButtons + [button], 1, TRUE);
            }
        }
    }
}

// pragma inline
HandleCOMMAND(integer iSender, integer iNum, string sStr, key kID)
{
if (iNum>=COMMAND_OWNER && iNum<=COMMAND_WEARER)
        {
            string test=llToLower(sStr);
            if (sStr == "refreshmenu")
            {
                g_lButtons = [];
                llMessageLinked(LINK_SET, MENU_REQUEST, g_sSubMenu, NULL_KEY);
            }
            else if (sStr == g_sBellChatPrefix)
            {// the command prefix + bell without any extentsion is used in chat
                //give this plugin's menu to kID
                DoMenu(kID);
            }            
            else if (startswith(test,g_sBellChatPrefix))
            {
                // it is a chat commad for the bell so process it
                list lParams = llParseString2List(test, [" "], []);
                string sToken = llList2String(lParams, 1);
                string sValue = llList2String(lParams, 2);

                if (sToken=="volume")
                {
                    integer n=(integer)sValue;
                    if (n<1) n=1;
                    if (n>10) n=10;
                    g_fVolume=(float)n/10;
                    SaveBellSettings();
                    Notify(kID,"Bell volume set to "+(string)n, TRUE);
                }
                else if (sToken=="delay")
                {
                    g_fSpeed=(float)sValue;
                    if (g_fSpeed<g_fSpeedMin) g_fSpeed=g_fSpeedMin;
                    if (g_fSpeed>g_fSpeedMax) g_fSpeed=g_fSpeedMax;
                    SaveBellSettings();
                    llWhisper(0,"Bell delay set to "+llGetSubString((string)g_fSpeed,0,2)+" seconds.");
                }
                else if (sToken=="show" || sToken=="hide")
                {
                    if (sToken=="show")
                    {
                        g_iBellShow=TRUE;
                        SetBellElementAlpha(1.0);
                        Notify(kID,"The bell is now visible.",TRUE);
                    }
                    else
                    {
                        g_iBellShow=FALSE;
                        SetBellElementAlpha(0.0);
                        Notify(kID,"The bell is now invisible.",TRUE);
                    }
                    SaveBellSettings();

                }
                else if (sToken=="on")
                {
                    if (iNum!=COMMAND_GROUP)
                    {
                        if (g_iBellOn==0)
                        {
                            g_iBellOn=iNum;
                            if (!g_iHasControl)
                                llRequestPermissions(g_kWearer,PERMISSION_TAKE_CONTROLS);

                                SaveBellSettings();
                            Notify(kID,"The bell rings now.",TRUE);
                            if (g_iLocalMenuCall)
                            {
                                g_iLocalMenuCall=FALSE;
                                DoMenu(kID);
                            }
                        }
                    }
                    else
                    {
                        Notify(kID,"Group users or Open Acces users cannot change the ring status of the bell.",TRUE);
                    }
                }
                else if (sToken=="off")
                {
                    if ((g_iBellOn>0)&&(iNum!=COMMAND_GROUP))
                    {
                        g_iBellOn=0;

                        if (g_iHasControl)
                        {
                            llReleaseControls();
                            g_iHasControl=FALSE;

                        }

                        SaveBellSettings();
                        Notify(kID,"The bell is now quiet.",TRUE);
                    }
                    else
                    {
                        Notify(kID,"Group users or Open Access users cannot change the ring status of the bell.",TRUE);
                    }
                    if (g_iLocalMenuCall)
                    {
                        g_iLocalMenuCall=FALSE;
                        DoMenu(kID);
                    }
                }
                else if (sToken=="nextsound")
                {
                    g_iCurrentBellSound++;
                    if (g_iCurrentBellSound>=g_iBellSoundCount)
                    {
                        g_iCurrentBellSound=0;
                    }
                    g_kCurrentBellSound=llList2Key(g_listBellSounds,g_iCurrentBellSound);
                    Notify(kID,"Bell sound changed, now using "+(string)(g_iCurrentBellSound+1)+" of "+(string)g_iBellSoundCount+".",TRUE);
                }
                // show the help
                else if (sToken=="help" || sToken=="?")
                {
                    ShowHelp(kID);
                }
                // let the bell ring one time
                else if (sToken=="ring")
                {
                    // update variable for time check
                    g_fNextRing=llGetTime()+g_fSpeed;
                    // and play the sound
                    llPlaySound(g_kCurrentBellSound,g_fVolume);
                }

            }
        }
}

// pragma inline
HandleDIALOG(integer iSender, integer iNum, string sStr, key kID)
{
    if (iNum==DIALOG_RESPONSE)
    {
        //str will be a 2-element, pipe-delimited list in form pagenum|response
        list lMenuParams = llParseString2List(sStr, ["|"], []);
        key kAV = llList2String(lMenuParams, 0);
        string sMessage = llList2String(lMenuParams, 1);
        integer iPage = (integer)llList2String(lMenuParams, 2);

        if (kID == g_kDialogID)
        {
            integer nRemenu=FALSE;
            if (sMessage == UPMENU)
            {            
                llMessageLinked(LINK_SET, MENU_SUBMENU, g_sParentMenu, kAV);
            }
            else if (~llListFindList(g_lLocalButtons, [sMessage]))
            {
                nRemenu=TRUE;
                if (sMessage == "Vol +")
                {
                    g_fVolume+=g_fVolumeStep;
                    if (g_fVolume>1.0)
                    {
                        g_fVolume=1.0;
                    }
                    SaveBellSettings();
                }
                else if (sMessage == "Vol -")
                    // be more quiet, and store the value
                {
                    g_fVolume-=g_fVolumeStep;
                    if (g_fVolume<0.1)
                    {
                        g_fVolume=0.1;
                    }
                    SaveBellSettings();
                }
                else if (sMessage == "Delay +")
                    // dont annoy people and ring slower
                {
                    g_fSpeed+=g_fSpeedStep;
                    if (g_fSpeed>g_fSpeedMax)
                    {
                        g_fSpeed=g_fSpeedMax;
                    }
                    SaveBellSettings();
                }
                else if (sMessage == "Delay -")
                    // annoy the hell out of the, ring plenty, ring often
                {
                    g_fSpeed-=g_fSpeedStep;
                    if (g_fSpeed<g_fSpeedMin)
                    {
                        g_fSpeed=g_fSpeedMin;
                    }
                    SaveBellSettings();
                }
                else if (sMessage == "Next Sound")
                    // choose another sound for the bell
                {
                    g_iCurrentBellSound++;
                    if (g_iCurrentBellSound>=g_iBellSoundCount)
                    {
                        g_iCurrentBellSound=0;
                    }
                    g_kCurrentBellSound=llList2Key(g_listBellSounds,g_iCurrentBellSound);

                    SaveBellSettings();
                }
                // show help
                else if (sMessage=="~Chat Help")
                {
                    ShowHelp(kAV);
                }
                //added a button to ring the bell. same call as when walking.
                else if (sMessage == "Ring It")
                {
                    // update variable for time check
                    g_fNextRing=llGetTime()+g_fSpeed;
                    // and play the sound
                    llPlaySound(g_kCurrentBellSound,g_fVolume);
                    //Debug("Bing");
                }

            }
            else if (sMessage == g_sBellOff || sMessage == g_sBellOn)
                // someone wants to change if the bell rings or not
            {
                string s;
                if (g_iBellOn>0)
                {
                    s="bell off";
                }
                else
                {
                    s="bell on";
                }
                llMessageLinked(LINK_SET,COMMAND_NOAUTH,s,kAV);

                // LM listerer wil tkae care of showing the menua
                g_iLocalMenuCall=TRUE;
                nRemenu=FALSE;
            }
            else if (sMessage == g_sBellShow || sMessage == g_sBellHide)
                // someone wants to hide or show the bell
            {
                g_iBellShow=!g_iBellShow;
                if (g_iBellShow)
                {
                    SetBellElementAlpha(1.0);
                }
                else
                {
                    SetBellElementAlpha(0.0);
                }
                SaveBellSettings();
                nRemenu=TRUE;
            }
            else if (~llListFindList(g_lButtons, [sMessage]))
            {
                //we got a submenu selection
                llMessageLinked(LINK_SET, MENU_SUBMENU, sMessage, kAV);
            }
            
            if (nRemenu)
            { 
                DoMenu(kAV);
            }
        }
    }
}

/*---------------//
//  MAIN CODE    //
//---------------*/
default
{
    state_entry()
    {
        // key of the owner
        g_kWearer=llGetOwner();
        g_sSubPrefix=AutoPrefix();
        string s=GetDBPrefix();
        g_sBellSaveToken = s + g_sBellSaveToken;

        // reset script time used for ringing the bell in intervalls
        llResetTime();

        // build up list of prims with bell elements
        BuildBellElementList();

        PrepareSounds();
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
        else if ((iNum >= DIALOG_TIMEOUT) && (iNum <= DIALOG_REQUEST))
        {
            HandleDIALOG(iSender,iNum,sStr,kID);
        }
        else if ((iNum >= COMMAND_OWNER) && (iNum <= COMMAND_WEARERLOCKEDOUT))
        {
            HandleCOMMAND(iSender,iNum,sStr,kID);
        }
    } 

    control( key kID, integer nHeld, integer nChange )
    {
        if (!g_iBellOn) 
            return;
        if ( nHeld & (CONTROL_LEFT|CONTROL_RIGHT|CONTROL_DOWN|CONTROL_UP|CONTROL_ROT_LEFT|CONTROL_ROT_RIGHT|CONTROL_FWD|CONTROL_BACK) )
        {
            if (llGetTime()>g_fNextRing)
            {
                g_fNextRing=llGetTime()+g_fSpeed;
                llPlaySound(g_kCurrentBellSound,g_fVolume);
            }
        }
    }

    run_time_permissions(integer nParam)
    {
        if( nParam & PERMISSION_TAKE_CONTROLS)
        {
            llTakeControls( CONTROL_DOWN|CONTROL_UP|CONTROL_FWD|CONTROL_BACK|CONTROL_LEFT|CONTROL_RIGHT|CONTROL_ROT_LEFT|CONTROL_ROT_RIGHT, TRUE, TRUE);
            g_iHasControl=TRUE;
        }
    }
}