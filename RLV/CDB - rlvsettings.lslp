/*--------------------------------------------------------------------------------**
**  File: CDB - settings                                                          **
** ------------------------------------------------------------------------------ **
**  Version: 6.00.001                                                             **
** ------------------------------------------------------------------------------ **
** Licensed under the GPLv2, with the additional requirement that these scripts   **
** remain "full perms" in Second Life®.  See "CollarDB License" for details.      **
** ------------------------------------------------------------------------------ **
** ©2014 CollarDB and Individual Contributors                                     **
**--------------------------------------------------------------------------------*/

//CollarDB - rlvmisc + rlvsit
/*-------------//
//  VARIABLES  //
//-------------*/

list g_lOwners;

string g_sParentMenu = "RLV";
string g_sSubMenu_misc = "Misc";
string g_sDBToken_misc = "rlvmisc";
string g_sSubMenu_sit = "Sit";
string g_sDBToken_sit = "rlvsit";
string g_sSubMenu_talk = "Talk";
string g_sDBToken_talk = "rlvtalk";
string g_sSubMenu_tp = "Map/TP";
string g_sDBToken_tp = "rlvtp";

string g_sCurrMenu;

list g_lSettings_tp; //2-strided list in form of [option, param]
list g_lRLVcmds_tp = [ //4-strided list in form of [rlvCommand, Pretty Command, Description, Bool Force]
    "tplm", "LM", "Teleport to Landmark", FALSE,
    "tploc", "Loc", "Teleport to Location", FALSE,
    "tplure", "Lure", "Teleport by Friend", FALSE,
    "showworldmap", "Map", "World Map", FALSE,
    "showminimap", "Minimap", "Mini Map", FALSE,
    "showloc", "ShowLoc", "Current Location", FALSE
        ];
        
list g_lSettings_talk;//2-strided list in form of [option, param]
list g_lRLVcmds_talk = [ //4-strided list in form of [rlvCommand, Pretty Command, Description, Bool Force]
    "sendchat", "Chat", "Ability to Send Chat", FALSE,
    "chatshout", "Shouting", "Ability to Shout Chat", FALSE,
    "chatnormal", "Normal", "Ability to Speak Without Whispering", FALSE,
    "startim", "StartIM", "Ability to Start IM Sessions", FALSE,
    "sendim", "SendIM", "Ability to Send IM", FALSE,
    "recvchat", "RcvChat", "Ability to Receive Chat", FALSE,
    "recvim", "RcvIM", "Ability to Receive IM", FALSE,
    "emote", "Emote",  "Allowed length of Emotes", FALSE,
    "recvemote", "RcvEmote", "Ability to Receive Emote", FALSE
        ];

list g_lSettings_misc;//2-strided list in form of [option, param]
list g_lRLVcmds_misc = [
    "shownames", "Names", "See Avatar Names", FALSE,
    "fly", "Fly", "Ability to Fly", FALSE,
    "fartouch", "Touch", "Touch Objects 1.5M+ Away", FALSE,
    "edit", "Edit", "Edit Objects", FALSE,
    "rez", "Rez",  "Rez Objects", FALSE,
    "showinv", "Inventory", "View Inventory", FALSE,
    "viewnote", "Notecards", "View Inventory", FALSE,
    "viewscript", "Scripts", "View Inventory", FALSE,
    "viewtexture", "Textures", "View Textures", FALSE,
    "showhovertexthud", "Hud", "See hover text from Hud objects", FALSE,
    "showhovertextworld", "World", "See hover text from ojects in world", FALSE
        ];

list g_lSettings_sit;//2-strided list in form of [option, param]
list g_lRLVcmds_sit = [
    "unsit", "Stand", "Ability to Stand If Seated", FALSE,           //may stand, if seated
    "sittp", "Sit", "Ability to Sit On Objects 1.5M+ Away", FALSE, //may sit 1.5M+ away
    "sit", "SitNow", "Force Sit", TRUE,
    "forceunsit", "StandNow", "Force Stand", TRUE
        ];
        
float g_fScanRange = 20.0;//range we'll scan for scripted objects when doing a force-sit
key g_sMenuUser;//used to remember who to give the menu to after scanning
list g_lSitButtons;
string g_sSiTPrompt;
list g_lSitKeys;

// Variables used for sit memory function
string  g_sSitTarget = "";
integer g_iSitMode;
integer g_iSitChan = 324590;    // Now randomized in state_entry
integer g_iSitListener;
float   g_fRestoreDelay = 1.0;
integer g_iRestoreCount = 0;
float   g_fPollDelay = 10.0;

string TURNON = "Allow";
string TURNOFF = "Forbid";
string DESTINATIONS = "Destinations";

key kMenuID;
key g_kSitID;
key lmkMenuID;

key g_kLMID;//store the request id here when we look up  a LM

integer g_iReturnMenu = FALSE;
integer g_iRLVOn=TRUE; // make sure the rlv only gets activated 


$import lib.MessageMap.lslm ();
$import lib.CommonVariables.lslm ();
$import lib.CommonFunctions.lslm ();


/*---------------//
//  FUNCTIONS    //
//---------------*/

integer IsUnsitEnabled()
{
    integer iIndex = llListFindList(g_lSettings_sit, ["unsit"]);
    string  sValue = llList2String(g_lSettings_sit, iIndex + 1);

    if (sValue == "n")
        return 0;

    return 1;
}

// -- SIT --
Menu(key kID, list lRLVcmds, list lSettings, string sCurrMenu)
{
    g_sCurrMenu = sCurrMenu;
    if (!g_iRLVOn)
    {
        Notify(kID, "RLV features are now disabled in this collar. You can enable those in RLV submenu. Opening it now.", FALSE);
        llMessageLinked(LINK_SET, MENU_SUBMENU, "RLV", kID);
        return;
    }

     //build prompt showing current settings
    //make enable/disable buttons
    string sPrompt = "Pick an option";
    sPrompt += "\nCurrent Settings: ";
    list lButtons;


    //Default to hide emote, chatnormal(forced whisper) and chatshout(ability to shout).
    //If they are allowed, they will be set to TRUE in the following block
    integer iShowChatNormal  = FALSE;
    integer iShowChatShout   = FALSE;
    integer iShowEmote       = FALSE;
    if (llList2String(lSettings, (llListFindList(lSettings, ["sendchat"])+1)) == "n"){
        //Debug("hide chatshout and chatnormal");
        iShowEmote = TRUE;
    }
    else {
        //Debug("show chatnormal");
        iShowChatNormal = TRUE;

        if (llList2String(lSettings, (llListFindList(lSettings, ["chatnormal"])+1)) == "n"){
            //Debug("hide chatshout");
        }
        else {
            //Debug("show chatshout");
            iShowChatShout   = TRUE;
        }
    }
    //

    integer n;
    integer iStop = llGetListLength(lRLVcmds);
    for (n = 0; n < iStop; n=n+4)
    {
        //see if there's a setting for this in the settings list
        string sCmd = llList2String(lRLVcmds, n);
        string sPretty = llList2String(lRLVcmds, n+1);
        string sDesc = llList2String(lRLVcmds, n+2);
        integer iImmediate = llList2Integer(lRLVcmds, n+3);        
        integer iIndex = llListFindList(lSettings, [sCmd]);

        if ((sCmd == "chatnormal" && !iShowChatNormal) || (sCmd == "chatshout" && !iShowChatShout) || (sCmd == "emote" && !iShowEmote))
        {
            //Debug("skipping: "+llList2String(g_lRLVcmds_talk, n));
        }
        else if (!iImmediate)
        {
            if (iIndex == -1)
            {
                //if this cmd not set, then give button to enable
                if (sPretty=="Emote"){
                    //When sendchat='n' then emote defaults to short mode (rem), so you allow long emotes(add)......
                    lButtons += [TURNON + " " + sPretty];
                    sPrompt += "\n" + sPretty + " = Short (" + sDesc + ")";
                }
                else
                {                
                    lButtons += [TURNOFF + " " + sPretty];
                    sPrompt += "\n" + sPretty + " = Enabled (" + sDesc + ")";
                }
            }
            else
            {
                //else this cmd is set, then show in prompt, and make button do opposite
                //get value of setting
                string sValue = llList2String(lSettings, iIndex + 1);
                
                if (sValue == "y" || (sPretty=="Emote" && sValue == "add"))
                {
                    lButtons += [TURNOFF + " " + sPretty];
                    if (sPretty=="Emote") {
                        sPrompt += "\n" + sPretty + " = Long (" + sDesc + ")";
                    }
                    else {
                        sPrompt += "\n" + sPretty + " = Enabled (" + sDesc + ")";
                    }
                }
                else if (sValue == "n" || (sPretty=="Emote" && sValue == "rem"))
                {
                    lButtons += [TURNON + " " + sPretty];
                    if (sPretty=="Emote") {
                        sPrompt += "\n" + sPretty + " = Short (" + sDesc + ")";
                    }
                    else {
                        sPrompt += "\n" + sPretty + " = Disabled (" + sDesc + ")";
                    }                    
                }
            }
        }
        else
        {
            lButtons += [sPretty];
            sPrompt += "\n" + sPretty + " = " + sDesc;
        }        
    }
    
    if (sCurrMenu == "map/tp")
        lButtons += [DESTINATIONS];

    //give an Allow All button
    lButtons += [TURNON + " All"];
    lButtons += [TURNOFF + " All"];
    kMenuID = Dialog(kID, sPrompt, lButtons, [UPMENU], 0);
}

LandmarkMenu(key kAv)
{
    list lButtons;

    integer n;
    integer iStop = llGetInventoryNumber(INVENTORY_LANDMARK);
    for (n = 0; n < iStop; n++)
    {
        string sName = llGetInventoryName(INVENTORY_LANDMARK, n);
        lButtons += [sName];
    }

    lmkMenuID = Dialog(kAv, "Pick a landmark to teleport to.", lButtons, [UPMENU], 0);
}

list UpdateSettings(list lSettings)
{
    list lTempSettings;
    //build one big string from the settings list
    //llOwnerSay("TP settings: " + llDumpList2String(g_lSettings_sit, ","));
    integer iSettingsLength = llGetListLength(lSettings);
    if (iSettingsLength > 0)
    {
        string sOut;
        integer n;
        list lNewList;
        for (n = 0; n < iSettingsLength; n = n + 2)
        {
            string sToken = llList2String(lSettings, n);
            string sValue = llList2String(lSettings, n + 1);

            if (sToken == "emote")
            {
                if (sValue == "y")
                {
                    sValue = "add";
                }
                else if (sValue == "n")
                {
                    sValue = "rem";
                }
            }
            
            lNewList += [sToken + "=" + sValue];
            if (sValue!="y")
            {
                lTempSettings+=[sToken, sValue];
            }
        }
        sOut = llDumpList2String(lNewList, ",");
        //output that string to viewer
        llMessageLinked(LINK_SET, RLV_CMD, sOut, NULL_KEY);
    }
    return lTempSettings;
}

SaveSettings(string sDBToken, list lSettings)
{
    //save to DB
    if (llGetListLength(lSettings)>0)
        llMessageLinked(LINK_SET, SETTING_SAVE, sDBToken + "=" + llDumpList2String(lSettings, ","), NULL_KEY);
    else
        llMessageLinked(LINK_SET, SETTING_DELETE, sDBToken, NULL_KEY);

}

list ClearSettings(string sDBToken)
{
    //clear settings list
    list lSettings = [];
    //remove tpsettings from DB
    llMessageLinked(LINK_SET, SETTING_DELETE, sDBToken, NULL_KEY);
    //main RLV script will take care of sending @clear to viewer
    return lSettings;
}

list RLVCmdSet(integer iAuth, list lSettings, string sRLVCmd, string sParam, integer iForce)
{

    if (iAuth == COMMAND_WEARER)
    {
        Notify(g_kWearer,"Sorry, but RLV commands may only be given by owner, secowner, or group (if set).",FALSE);
        return lSettings;
    }
    string sNewRLVCmd = sRLVCmd + "=" + sParam;
    
    if (iForce)
    {
        
        if (sRLVCmd == "unsit" && sParam == "force")
        {
            integer iIndex = llListFindList(lSettings, ["unsit"]); // Check for ability to unsit
        
            if (iIndex>=0)
                if (llList2String(lSettings, iIndex + 1) != "n")
                    iIndex=-1;

            if (iIndex!=-1) // If standing is disabled
                sNewRLVCmd="unsit=y," + sNewRLVCmd + ",unsit=n";
        }
        else if (sRLVCmd == "sit") 
        {
            if ((key)sParam)
                sNewRLVCmd=sRLVCmd + ":" + sParam + "=force";
        }

        llMessageLinked(LINK_SET, RLV_CMD, sNewRLVCmd, NULL_KEY);    
    }
    else
    {
        integer iIndex = llListFindList(lSettings, [sRLVCmd]);
        if (iIndex == -1)
        {
            //we don't alread have this exact setting.  add it
            lSettings += [sRLVCmd, sParam];
        }
        else
        {
            //we already have a setting for this option.  update it.
            lSettings = llListReplaceList(lSettings, [sRLVCmd, sParam], iIndex, iIndex + 1);
        }
    }
    
    return lSettings;
}

/*---------------//
//  HANDLERS     //
//---------------*/
// pragma inline
HandleHTTPDB(integer iSender, integer iNum, string sStr, key kID)
{
    if (iNum == SETTING_RESPONSE)
    {
        list lParams = llParseString2List(sStr, ["="], []);
        integer iChange = FALSE;
        if (llList2String(lParams, 0) == g_sDBToken_sit)
        {
            g_lSettings_sit = llParseString2List(llList2String(lParams, 1), [","], []);
            g_lSettings_sit = UpdateSettings(g_lSettings_sit);

        }
        else if (llList2String(lParams, 0) == g_sDBToken_misc)
        {
            g_lSettings_misc = llParseString2List(llList2String(lParams, 1), [","], []);
            g_lSettings_misc = UpdateSettings(g_lSettings_misc);
        }
        else if (llList2String(lParams, 0) == g_sDBToken_talk)
        {
            g_lSettings_talk = llParseString2List(llList2String(lParams, 1), [","], []);
            g_lSettings_talk = UpdateSettings(g_lSettings_talk);
        }
        else if (llList2String(lParams, 0) == g_sDBToken_tp)
        {
            g_lSettings_tp = llParseString2List(llList2String(lParams, 1), [","], []);
            g_lSettings_tp = UpdateSettings(g_lSettings_tp);
        }    
    }
}
// pragma inline
HandleDIALOG(integer iSender, integer iNum, string sStr, key kID)
{
if (iNum == DIALOG_TIMEOUT)
        {
            if (kID == kMenuID)
            {
                g_iReturnMenu = FALSE;
            }
        }
        else if (iNum == DIALOG_RESPONSE)
        {
            if (llListFindList([kMenuID, g_kSitID], [kID]) != -1)
            {//it's one of our menus
                list lMenuParams = llParseString2List(sStr, ["|"], []);
                key kAv = (key)llList2String(lMenuParams, 0);          
                string sMessage = llList2String(lMenuParams, 1);                                         
                integer iPage = (integer)llList2String(lMenuParams, 2);                
                if (kID == kMenuID)
                {
                    if (sMessage == UPMENU)
                    {
                        llMessageLinked(LINK_SET, MENU_SUBMENU, g_sParentMenu, kAv);
                        g_iReturnMenu = FALSE;
                    }
                    else
                    {
                        //if str == an immediate command, send cmd
                        //else if str == a stored command, do that
        
                        if (sMessage == "SitNow")
                        {
                            //give menu of nearby objects that have scripts in them
                            //this assumes that all the objects you may want to force your sub to sit on
                            //have scripts in them
                            g_sMenuUser = kAv;
                            llSensor("", NULL_KEY, SCRIPTED, g_fScanRange, PI);
                        }
                        else if (sMessage == "StandNow")
                        {
        
                            llMessageLinked(LINK_SET, COMMAND_NOAUTH, "unsit=force", kAv);
                            g_iReturnMenu = TRUE;
                        }
                        else
                        {
                            //we got a command to enable or disable something, like "Enable LM"
                            //get the actual command name by looking up the pretty name from the message
        
                            list lParams = llParseString2List(sMessage, [" "], []);
                            string sSwitch = llList2String(lParams, 0);
                            string sCmd = llList2String(lParams, 1);
                            
                            integer iIndex;
                            if (g_sCurrMenu == "sit")
                                iIndex=llListFindList(g_lRLVcmds_sit, [sCmd]);
                            else if (g_sCurrMenu == "misc")
                                iIndex=llListFindList(g_lRLVcmds_misc, [sCmd]);
                            else if (g_sCurrMenu == "talk")
                                iIndex=llListFindList(g_lRLVcmds_talk, [sCmd]);
                            else if (g_sCurrMenu == "map/tp")
                                iIndex=llListFindList(g_lRLVcmds_tp, [sCmd]);    
                                
                            if (sCmd == "All")
                            {
                                //handle the "Allow All" and "Forbid All" commands
                                string ONOFF;
                                //decide whether we need to switch to "y" or "n"
                                if (sSwitch == TURNOFF)
                                {
                                    //enable all functions (ie, remove all restrictions
                                    ONOFF = "n";
                                }
                                else if (sSwitch == TURNON)
                                {
                                    ONOFF = "y";
                                }
        
                                //loop through rlvcmds to create list
                                string sOut;
                                integer n;
                                integer iStop;
                                if (g_sCurrMenu == "sit")
                                    iStop=llGetListLength(g_lRLVcmds_sit);
                                else if (g_sCurrMenu == "misc")
                                    iStop=llGetListLength(g_lRLVcmds_misc);
                                else if (g_sCurrMenu == "talk")
                                    iStop=llGetListLength(g_lRLVcmds_talk);
                                else if (g_sCurrMenu == "map/tp")
                                    iStop=llGetListLength(g_lRLVcmds_tp);                                    
                                    
                                for (n = 0; n < iStop; n=n+4)
                                {
                                    //prefix all but the first value with a comma, so we have a comma-separated list
                                    if (n)
                                    {
                                        sOut += ",";
                                    }
                                    if (g_sCurrMenu == "sit")
                                        sOut += llList2String(g_lRLVcmds_sit, n) + "=" + ONOFF;
                                    else if (g_sCurrMenu == "misc")
                                        sOut += llList2String(g_lRLVcmds_misc, n) + "=" + ONOFF;
                                    else if (g_sCurrMenu == "talk")
                                        sOut += llList2String(g_lRLVcmds_talk, n) + "=" + ONOFF;
                                    else if (g_sCurrMenu == "map/tp")
                                        sOut += llList2String(g_lRLVcmds_tp, n) + "=" + ONOFF;
                                }
                                llMessageLinked(LINK_SET, COMMAND_NOAUTH, sOut, kAv);
                                g_iReturnMenu = TRUE;
                            }
                            else if (iIndex != -1)
                            {
                                string sOut;
                                if (g_sCurrMenu == "sit")
                                    sOut = llList2String(g_lRLVcmds_sit, iIndex-1);
                                else if (g_sCurrMenu == "misc")
                                    sOut = llList2String(g_lRLVcmds_misc, iIndex-1);
                                 else if (g_sCurrMenu == "talk")
                                    sOut = llList2String(g_lRLVcmds_talk, iIndex-1);
                                 else if (g_sCurrMenu == "map/tp")
                                    sOut = llList2String(g_lRLVcmds_tp, iIndex-1);
                                    
                                sOut += "=";
                                if (sSwitch == TURNON)
                                {
                                    sOut += "y";
                                }
                                else if (sSwitch == TURNOFF)
                                {
                                    sOut += "n";
                                }
                                //send rlv command out through auth system as though it were a chat command, just to make sure person who said it has proper authority
                                llMessageLinked(LINK_SET, COMMAND_NOAUTH, sOut, kAv);
                                g_iReturnMenu = TRUE;
                            }
                            else if (sMessage == DESTINATIONS)
                            {
                                //give menu of LMs
                                LandmarkMenu(kAv);
                            }
                            else
                            {
                                //something went horribly wrong.  We got a command that we can't find in the list
                            }
                        }
                    }
                }
                else if (kID == lmkMenuID)
                {
                    lMenuParams = llParseString2List(sStr, ["|"], []);
                    kAv = (key)llList2String(lMenuParams, 0);
                    sMessage = llList2String(lMenuParams, 1);
                    iPage = (integer)llList2String(lMenuParams, 2);
                    //got a response to the LM menu.
                    if (sMessage == UPMENU)
                    {
                        Menu(kID, g_lRLVcmds_tp, g_lSettings_tp, llToLower(g_sSubMenu_tp));;
                    }
                    else if (llGetInventoryType(sMessage) == INVENTORY_LANDMARK)
                    {
                        llMessageLinked(LINK_SET, COMMAND_NOAUTH, "tp " + sMessage, kAv);
                        g_iReturnMenu = TRUE;
                    }
                }
                else if (kID == g_kSitID)
                {
                    if (sMessage==UPMENU)
                    {
                        Menu(kAv, g_lRLVcmds_sit, g_lSettings_sit, llToLower(g_sSubMenu_sit));
                    }
                    else if ((key)sMessage)
                    {
                        //we heard a number for an object to sit on
                        //integer seatiNum = (integer)sMessage - 1;
                        g_iReturnMenu = TRUE;
                        llMessageLinked(LINK_SET, COMMAND_NOAUTH, "sit:" + sMessage + "=force", kAv);
                    }                            
                }                 
            }
        }
}
// pragma inline
HandleMENU(integer iSender, integer iNum, string sStr, key kID)
{
    if (iNum == MENU_SUBMENU)
    {
        if (sStr == g_sSubMenu_misc)
        {
            Menu(kID, g_lRLVcmds_misc, g_lSettings_misc, llToLower(g_sSubMenu_misc));
        }
        else if (sStr == g_sSubMenu_sit)
        {
            Menu(kID, g_lRLVcmds_sit, g_lSettings_sit, llToLower(g_sSubMenu_sit));
        }
        else if (sStr == g_sSubMenu_talk)
        {
            Menu(kID, g_lRLVcmds_talk, g_lSettings_talk, llToLower(g_sSubMenu_talk));
        }
        else if (sStr == g_sSubMenu_tp)
        {
            Menu(kID, g_lRLVcmds_tp, g_lSettings_tp, llToLower(g_sSubMenu_tp));
        }        
    }
    else if (iNum == MENU_REQUEST && sStr == g_sParentMenu)
    {
        llMessageLinked(LINK_SET, MENU_RESPONSE, g_sParentMenu + "|" + g_sSubMenu_misc, NULL_KEY);
        llMessageLinked(LINK_SET, MENU_RESPONSE, g_sParentMenu + "|" + g_sSubMenu_sit, NULL_KEY);
        llMessageLinked(LINK_SET, MENU_RESPONSE, g_sParentMenu + "|" + g_sSubMenu_talk, NULL_KEY);
        llMessageLinked(LINK_SET, MENU_RESPONSE, g_sParentMenu + "|" + g_sSubMenu_tp, NULL_KEY);
    }
    /*
    else if (iNum == MENU_RESPONSE)
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
    */   
}
// pragma inline
HandleCOMMAND(integer iSender, integer iNum, string sStr, key kID)
{
    if (iNum >= COMMAND_OWNER && iNum <= COMMAND_WEARER)
    {
        //added for chat command for direct menu acceess
        if (llToLower(sStr) == llToLower(g_sSubMenu_misc))
        {
            Menu(kID, g_lRLVcmds_misc, g_lSettings_misc, llToLower(g_sSubMenu_misc));
            return;
        }
        else if (llToLower(sStr) == "sitmenu")
        {
            Menu(kID, g_lRLVcmds_sit, g_lSettings_sit, llToLower(g_sSubMenu_sit));
            return;
        }
        else if (llToLower(sStr) == "talk")
        {
            Menu(kID, g_lRLVcmds_talk, g_lSettings_talk, llToLower(g_sSubMenu_talk));
            return;
        }
        else if (llToLower(sStr) == "tp")
        {
            Menu(kID, g_lRLVcmds_tp, g_lSettings_tp, llToLower(g_sSubMenu_tp));
            return;
        }            
        else if (llToLower(sStr) == "sitnow")
        {
            if (!g_iRLVOn)
            {
                Notify(kID, "RLV features are now disabled in this collar. You can enable those in RLV submenu. Opening it now.", FALSE);
                llMessageLinked(LINK_SET, MENU_SUBMENU, "RLV", kID);
                return;
            }
            //give menu of nearby objects that have scripts in them
            //this assumes that all the objects you may want to force your sub to sit on
            //have scripts in them
            g_sMenuUser = kID;
            llSensor("", NULL_KEY, SCRIPTED, g_fScanRange, PI);
            return;
        }
        else if (llSubStringIndex(sStr, "tp ") == 0)
        {
            //we got a "tp" command with an argument after it.  See if it corresponds to a LM in inventory.
            list lParams = llParseString2List(sStr, [" "], []);
            string sDest = llToLower(llList2String(lParams, 1));
            integer i=0;
            integer m=llGetInventoryNumber(INVENTORY_LANDMARK);
            string s;
            integer found=FALSE;
            for (i=0;i<m;i++)
            {
                s=llGetInventoryName(INVENTORY_LANDMARK,i);
                if (sDest==llToLower(s))
                {
                    g_kLMID = llRequestInventoryData(s);
                    found=TRUE;
                 }
            }
            if (!found)
            {
                Notify(kID,"The landmark '"+llList2String(lParams, 1)+"' has not been found in the collar of "+llKey2Name(g_kWearer)+".",FALSE);
            }
            if (g_iReturnMenu)
            {
                LandmarkMenu(kID);
            }
            return;
        }

        list lItems = llParseString2List(sStr, [","], []);
        integer n;
        integer iIdx;
        integer iStop = llGetListLength(lItems);
        integer iChange_misc = FALSE;   //set this to true if we see a setting that concerns us
        integer iChange_sit = FALSE;    //set this to true if we see a setting that concerns us
        integer iChange_talk = FALSE;    //set this to true if we see a setting that concerns us
        integer iChange_tp = FALSE;    //set this to true if we see a setting that concerns us

        for (n = 0; n < iStop; n++)
        {
            //split off the parameters (anything after a : or =)
            //and see if the thing being set concerns us
            string sThisItem = llList2String(lItems, n);
            list lParams = llParseString2List(sThisItem, ["=", ":"], []);
            string sRLVCmd = llList2String(lParams, 0);
            string sParam = llList2String(lParams, 1);

            if (sRLVCmd == "tpto")
            {
                llMessageLinked(LINK_SET, RLV_CMD, sThisItem, NULL_KEY);
            }                
            if (llListFindList(g_lRLVcmds_misc, [sRLVCmd]) != -1)
            {
                iIdx = llListFindList(g_lRLVcmds_misc, [sRLVCmd]);
                g_lSettings_misc = RLVCmdSet(iNum, g_lSettings_misc, sRLVCmd, sParam, llList2Integer(g_lRLVcmds_misc,iIdx+3));
                iChange_misc = TRUE;
            }
            if (llListFindList(g_lRLVcmds_sit, [sRLVCmd]) != -1)
            {
                iIdx = llListFindList(g_lRLVcmds_sit, [sRLVCmd]);
                g_lSettings_sit = RLVCmdSet(iNum, g_lSettings_sit, sRLVCmd, sParam, llList2Integer(g_lRLVcmds_sit,iIdx+3));
                iChange_sit = TRUE;
            }
            if (llListFindList(g_lRLVcmds_talk, [sRLVCmd]) != -1)
            {
                iIdx = llListFindList(g_lRLVcmds_talk, [sRLVCmd]);
                g_lSettings_talk = RLVCmdSet(iNum, g_lSettings_talk, sRLVCmd, sParam, llList2Integer(g_lRLVcmds_talk,iIdx+3));
                iChange_talk = TRUE;
            }
            if (llListFindList(g_lRLVcmds_tp, [sRLVCmd]) != -1)
            {
                string sOption = llList2String(llParseString2List(sThisItem, ["="], []), 0);
                if (sOption != sRLVCmd)
                {
                    return; //this keeps exceptions for tplure from getting set here if they are it is no problem just more data i nthe DB
                }                
                iIdx = llListFindList(g_lRLVcmds_tp, [sRLVCmd]);
                g_lSettings_tp = RLVCmdSet(iNum, g_lSettings_tp, sRLVCmd, sParam, llList2Integer(g_lRLVcmds_tp,iIdx+3));
                iChange_tp = TRUE;
            }                      
            else if (sRLVCmd == "clear")
            {
                g_lSettings_sit=ClearSettings(g_sDBToken_sit);
                g_lSettings_misc=ClearSettings(g_sDBToken_misc);
                g_lSettings_talk=ClearSettings(g_sDBToken_talk);
                g_lSettings_tp=ClearSettings(g_sDBToken_tp);
            }
        }
            if (iChange_misc)
            {
                g_lSettings_misc=UpdateSettings(g_lSettings_misc);
                SaveSettings(g_sDBToken_misc,g_lSettings_misc);
                if (g_iReturnMenu)
                {
                    Menu(kID, g_lRLVcmds_misc, g_lSettings_misc, llToLower(g_sSubMenu_misc));
                }
            }
            else if (iChange_sit)
            {
                g_lSettings_sit=UpdateSettings(g_lSettings_sit);
                SaveSettings(g_sDBToken_sit,g_lSettings_sit);
                if (g_iReturnMenu)
                {
                    Menu(kID, g_lRLVcmds_sit, g_lSettings_sit, llToLower(g_sSubMenu_sit));
                }
            }
            else if (iChange_talk)
            {
                g_lSettings_talk=UpdateSettings(g_lSettings_talk);
                SaveSettings(g_sDBToken_talk,g_lSettings_talk);
                if (g_iReturnMenu)
                {
                    Menu(kID, g_lRLVcmds_talk, g_lSettings_talk, llToLower(g_sSubMenu_talk));
                }
            } 
            else if (iChange_tp)
            {
                g_lSettings_tp=UpdateSettings(g_lSettings_tp);
                SaveSettings(g_sDBToken_tp,g_lSettings_tp);
                if (g_iReturnMenu)
                {
                    Menu(kID, g_lRLVcmds_tp, g_lSettings_tp, llToLower(g_sSubMenu_tp));
                }
            } 
    }
}
// pragma inline
HandleRLV(integer iSender, integer iNum, string sStr, key kID)
{
    if (iNum == RLV_REFRESH)
    {
        //rlvmain just started up.  Tell it about our current restrictions
        g_iRLVOn = TRUE;
        g_lSettings_sit = UpdateSettings(g_lSettings_sit);
        g_lSettings_misc = UpdateSettings(g_lSettings_misc);
        g_lSettings_talk = UpdateSettings(g_lSettings_talk);
        g_lSettings_tp = UpdateSettings(g_lSettings_tp);
        // If we had something stored in memory, engage restore mode
        if ((!IsUnsitEnabled()) && (g_sSitTarget != ""))
        {
            llSetTimerEvent(g_fRestoreDelay);
            g_iRestoreCount = 20;
            g_iSitMode = 1;
        }
        else
        {
            llSetTimerEvent(g_fPollDelay);
            g_iSitMode = 0;
        }
    }
    else if (iNum == RLV_CLEAR)
    {
        //clear db and local settings list
        g_lSettings_sit=ClearSettings(g_sDBToken_sit);
        g_lSettings_misc=ClearSettings(g_sDBToken_misc);
        g_lSettings_talk=ClearSettings(g_sDBToken_talk);
        g_lSettings_talk=ClearSettings(g_sDBToken_tp);
    }
    else if (iNum == RLV_OFF)        // rlvoff -> we have to turn the menu off too
    {
        g_iRLVOn=FALSE;
    }
    else if (iNum == RLV_ON)        // rlvon -> we have to turn the menu on again
    {
        g_iRLVOn=TRUE;
    }
}

/*---------------//
//  MAIN CODE    //
//---------------*/
default
{
    state_entry()
    {
        g_kWearer = llGetOwner();
        llSetTimerEvent(0.0);
                
      //  llOwnerSay((string)(llGetFreeMemory() / 1024) + " KB Free");
    }
    
    on_rez(integer iParam)
    {
        llSetTimerEvent(0.0);
    }
    
    link_message(integer iSender, integer iNum, string sStr, key kID)
    {
        if ((iNum >= SETTING_SAVE) && (iNum <= SETTING_EMPTY))
        {
            HandleHTTPDB(iSender,iNum,sStr,kID);
        }
        else if ((iNum >= MENU_REQUEST) && (iNum <= MENU_REMOVE))
        {
            HandleMENU(iSender,iNum,sStr,kID); 
        }
        else if ((iNum >= RLV_REFRESH) && (iNum <= RLV_ON))
        {
            HandleRLV(iSender,iNum,sStr,kID);
        }
        else if ((iNum >= DIALOG_TIMEOUT) && (iNum <= DIALOG_REQUEST))
        {
            HandleDIALOG(iSender,iNum,sStr,kID);
        }        
        else if ((iNum >= COMMAND_OWNER) && (iNum <= COMMAND_RLV_RELAY))
        {
            HandleCOMMAND(iSender,iNum,sStr,kID);
        }
    }
  

    timer()
    {
        // Nothing to do if RLV isn't enabled
        if (!g_iRLVOn)
            return;
        
        key kSitKey = llList2Key(llGetObjectDetails(g_kWearer, [OBJECT_ROOT]), 0);
        // If we are in memory mode...
        if (!g_iSitMode)
        {
            if (IsUnsitEnabled() || kSitKey == g_kWearer)
            { // either unsit is allowed or you are not sitting anywhere, nothing to remember then
                g_sSitTarget = "";
            }
            else if ((string)kSitKey != g_sSitTarget)
            {   // you are sitting somewhere you are not allowed to stand up from, then remember where it was
                g_sSitTarget = (string)kSitKey;
            }
        }
        // Restore mode
        else
        {
            integer iIndex;
            string  sSittpValue;

            // Do we really have something to do ?
            if (g_sSitTarget == "")
            {
                g_iSitMode = 0;
                llSetTimerEvent(g_fPollDelay);
                return;
            }

            // Did we successfully resit the sub ?
            if ((string)kSitKey == g_sSitTarget)
            {
                llOwnerSay("Sit Memory: Restored Forcesit on " + llKey2Name((key)g_sSitTarget));
                g_iSitMode = 0;
                llSetTimerEvent(g_fPollDelay);
                return;
            }

            // Count down retries...
            if (g_iRestoreCount > 0)
                g_iRestoreCount--;
            else
            {
                llOwnerSay("Sit Memory: Lucky day! All attempts at restoring forcesit failed, giving up.");
                g_iSitMode = 0;
                llSetTimerEvent(g_fPollDelay);
                return;
            }

            // Save the value of sittp as we need to temporarily enable it for forcesit
            iIndex = llListFindList(g_lSettings_sit, ["sittp"]);
            sSittpValue = llList2String(g_lSettings_sit, iIndex + 1);

            llMessageLinked(LINK_THIS, RLV_CMD, "sittp=y,sit:" + g_sSitTarget + "=force,sittp=" + sSittpValue, NULL_KEY);
        }
    }

    dataserver(key kID, string sData)
    {
        if (kID == g_kLMID)
        {
            //we just got back LM data from a "tp " command.  now do a rlv "tpto" there
            vector vGoTo = (vector)sData + llGetRegionCorner();
            string sCmd = "tpto:";
            sCmd += llDumpList2String([vGoTo.x, vGoTo.y, vGoTo.z], "/");//format the destination in form x/y/z, as rlv requires
            sCmd += "=force";
            llMessageLinked(LINK_SET, RLV_CMD, sCmd, "");
        }
    }
    
    sensor(integer iNum)
    {
        g_lSitButtons = [];
        g_sSiTPrompt = "Pick the object on which you want the sub to sit.  If it's not in the list, have the sub move closer and try again.\n";
        //give g_sMenuUser a list of things to choose from
        integer n;
        for (n = 0; n < iNum; n ++)
        {
            //don't add things named "Object"
            if (llDetectedName(n) != "Object")
            {
                g_lSitButtons += [llDetectedKey(n)];
            }
        }

        g_kSitID = Dialog(g_sMenuUser, g_sSiTPrompt, g_lSitButtons, [UPMENU], 0);
    }

    no_sensor()
    {
        //nothing close by to sit on, tell g_sMenuUser
        Notify(g_sMenuUser, "Unable to find sit targets.", FALSE);
    }
}