/*--------------------------------------------------------------------------------**
**  File: CDB - undress                                                           **
** ------------------------------------------------------------------------------ **
**  Version: 6.00.001                                                             **
** ------------------------------------------------------------------------------ **
** Licensed under the GPLv2, with the additional requirement that these scripts   **
** remain "full perms" in Second Life®.  See "CollarDB License" for details.      **
** ------------------------------------------------------------------------------ **
** ©2014 CollarDB and Individual Contributors                                     **
**--------------------------------------------------------------------------------*/

//CollarDB - rlvundress - 3.529
//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "CollarDB License" for details.
//give 3 menus:
//Clothing
//Attachment
//Folder

/*-------------//
//  VARIABLES  //
//-------------*/

string g_sSubMenu = "Un/Dress";
string g_sParentMenu = "RLV";

list g_lChildren = ["Clothing","Attachment"]; //,"LockClothing","LockAttachment"];    //,"LockClothing","UnlockClothing"];

string SELECT_CURRENT = "*InFolder";
string SELECT_RECURS= "*Recursively";
list g_lRLVcmds = ["attach","detach","remoutfit", "addoutfit","remattach","addattach"];

integer g_iSmartStrip=FALSE; //use @detachallthis isntead of remove
string SMARTON="? SmartStrip";
string SMARTOFF = "? SmartStrip";
string SMARTHELP = "#RLV Help";
string g_sSmartHelpCard = "How to set up your #RLV and use SmartStrip";
string g_sSmartToken="smartstrip";

list g_lSettings;    //2-strided list in form of [option, param]


list LOCK_CLOTH_POINTS = [
    "Gloves",
    "Jacket",
    "Pants",
    "Shirt",
    "Shoes",
    "Skirt",
    "Socks",
    "Underpants",
    "Undershirt",
    "Skin",
    "Eyes",
    "Hair",
    "Shape",
    "Alpha",
    "Tattoo",
    "Physics"
        ];


list DETACH_CLOTH_POINTS = [
    "Gloves",
    "Jacket",
    "Pants",
    "Shirt",
    "Shoes",
    "Skirt",
    "Socks",
    "Underpants",
    "Undershirt",
    "xx", //"skin", those are not to be detached, so we ignore them later
    "xx", //"eyes", those are not to be detached, so we ignore them later
    "xx", //"hair", those are not to be detached, so we ignore them later
    "xx", //"shape", those are not to be detached, so we ignore them later
    "Alpha",
    "Tattoo",
    "Physics"
        ];

list ATTACH_POINTS = [//these are ordered so that their indices in the list correspond to the numbers returned by llGetAttached
    "None",
    "Chest",
    "Skull",
    "Left Shoulder",
    "Right Shoulder",
    "Left Hand",
    "Right Hand",
    "Left Foot",
    "Right Foot",
    "Spine",
    "Pelvis",
    "Mouth",
    "Chin",
    "Left Ear",
    "Right Ear",
    "Left Eyeball",
    "Right Eyeball",
    "Nose",
    "R Upper Arm",
    "R Forearm",
    "L Upper Arm",
    "L Forearm",
    "Right Hip",
    "R Upper Leg",
    "R Lower Leg",
    "Left Hip",
    "L Upper Leg",
    "L Lower Leg",
    "Stomach",
    "Left Pec",
    "Right Pec",
    "Center 2",
    "Top Right",
    "Top",
    "Top Left",
    "Center",
    "Bottom Left",
    "Bottom",
    "Bottom Right",
    "Neck",
    "Avatar Center"
        ];

        
string ALL = "*All*";
string TICKED = "(*)";
string UNTICKED = "( )";

//variables for storing our various dialog ids
key g_kMainID;
key g_kClothID;
key g_kAttachID;
key g_kLockID;
key g_kLockAttachID;

integer g_iRLVTimeOut = 60;

integer g_iClothRLV = 78465;
integer g_iAttachRLV = 78466;
integer g_iListener;
key g_kMenuUser;

string g_sDBToken = "undress";
string g_sDBTokenLockAll = "DressAllLocked";
integer g_iRemenu = FALSE;

integer g_iRLVOn = FALSE;

list g_lLockedItems; // list of locked clothes
list g_lLockedAttach; // list of locked attachmemts

string g_sWearerName;
integer g_iAllLocked = 0;  //1=all clothes are locked on

integer g_iLastAuth; //last auth level

$import lib.MessageMap.lslm ();
$import lib.CommonVariables.lslm ();
$import lib.CommonFunctions.lslm ();



/*---------------//
//  FUNCTIONS    //
//---------------*/

MainMenu(key kID)
{
    string sPrompt = "Note: Many clothes, and almost all mesh, mixes layers and attachments. With a properly set up #RLV folder (click "+SMARTHELP+" for info), the SmartStrip option will allow these to be removed automatically. Otherwise, it is recommended to explore the #RLV Folders menu for a smoother un/dressing experience.\n\nPick an option.";
    list lButtons = g_lChildren;

    if (g_iAllLocked)  //are all clothing and attachments locked?
    {
        sPrompt += "\n all clothes and attachments are currently locked.";
        //skip the LockClothing and the LockAttachment buttons
        lButtons += ["UnLockAll"];
    }
    else
    {
        lButtons += ["LockClothing"];
        lButtons += ["LockAttachment"];
        lButtons += ["LockAll"];
    }
    if(g_iSmartStrip==TRUE)
    {
        sPrompt += "\nSmartStrip is on.";
        lButtons += SMARTOFF;
    }
    else
    {
        lButtons += SMARTON;
        sPrompt += "\nSmartStrip is off.";
    }
    lButtons+=SMARTHELP;    
    g_kMainID = Dialog(kID, sPrompt, lButtons+g_lButtons, [UPMENU], 0);
}

QueryClothing()
{    //open listener
    g_iListener = llListen(g_iClothRLV, "", g_kWearer, "");
    //start timer
    llSetTimerEvent(g_iRLVTimeOut);
    //send rlvcmd
    llMessageLinked(LINK_SET, RLV_CMD, "getoutfit=" + (string)g_iClothRLV, NULL_KEY);
}

ClothingMenu(key kID, string sStr)
{
    //str looks like 0110100001111
    //loop through CLOTH_POINTS, look at char of str for each
    //for each 1, add capitalized button
    string sPrompt = "Select an article of clothing to remove.";
    list lButtons = [];
    integer iStop = llGetListLength(DETACH_CLOTH_POINTS);
    integer n;
    for (n = 0; n < iStop; n++)
    {
        integer iWorn = (integer)llGetSubString(sStr, n, n);
        list item = [llList2String(DETACH_CLOTH_POINTS, n)];
        if (iWorn && llListFindList(g_lLockedItems,item) == -1)
        {
            if (llList2String(item,0)!="xx")
                lButtons += item;
        }
    }
    g_kClothID = Dialog(kID, sPrompt, lButtons, [UPMENU], 0);
}

LockMenu(key kID)
{
    g_iRemenu=FALSE;
    string sPrompt = "Select an article of clothing to un/lock.";
    list lButtons;
    if (llListFindList(g_lLockedItems,[ALL]) == -1)
        lButtons += [UNTICKED+ALL];
    else  lButtons += [TICKED+ALL];

    integer iStop = llGetListLength(LOCK_CLOTH_POINTS);
    integer n;
    for (n = 0; n < iStop; n++)
    {
        string sCloth = llList2String(LOCK_CLOTH_POINTS, n);
        if (llListFindList(g_lLockedItems,[sCloth]) == -1)
            lButtons += [UNTICKED+sCloth];
        else  lButtons += [TICKED+sCloth];
    }
    g_kLockID = Dialog(kID, sPrompt, lButtons, [UPMENU], 0);
}

QueryAttachments()
{    //open listener
    g_iListener = llListen(g_iAttachRLV, "", g_kWearer, "");
    //start timer
    llSetTimerEvent(g_iRLVTimeOut);
    //send rlvcmd
    llMessageLinked(LINK_SET, RLV_CMD, "getattach=" + (string)g_iAttachRLV, NULL_KEY);
}

QuerySingleAttachment(string sAttachmetn)
{    //open listener
    integer iChan=g_iAttachRLV + llListFindList(ATTACH_POINTS,[sAttachmetn]) +1;
    if (iChan == g_iAttachRLV) return;
    g_iListener = llListen((iChan), "", g_kWearer, "");
    //start timer
    llSetTimerEvent(g_iRLVTimeOut);
    //send rlvcmd
    llMessageLinked(LINK_SET, RLV_CMD, "getattach:"+sAttachmetn+"=" + (string)iChan, NULL_KEY);
}


LockAttachmentMenu(key kID)
{
    g_iRemenu=FALSE;
    string sPrompt = "Select an attachment to un/lock.";
    list lButtons;

    //put tick marks next to locked things
    integer iStop = llGetListLength(ATTACH_POINTS);
    integer n;
    for (n = 1; n < iStop; n++) //starting at 1 as "None" cannot be locked
    {
        string sAttach = llList2String(ATTACH_POINTS, n);
        if (llListFindList(g_lLockedAttach,[sAttach]) == -1)
            lButtons += [UNTICKED+sAttach];
        else  lButtons += [TICKED+sAttach];
    }
    g_kLockAttachID = Dialog(kID, sPrompt, lButtons, [UPMENU], 0);
}

DetachMenu(key kID, string sStr)
{

    //remember not to add button for current object
    //str looks like 0110100001111
    //loop through CLOTH_POINTS, look at char of str for each
    //for each 1, add capitalized button
    string sPrompt = "Select an attachment to remove.";

    //prevent detaching the collar itself
    integer myattachpoint = llGetAttached();

    list lButtons;
    integer iStop = llGetListLength(ATTACH_POINTS);
    integer n;
    for (n = 0; n < iStop; n++)
    {
        if (n != myattachpoint)
        {
            integer iWorn = (integer)llGetSubString(sStr, n, n);
            if (iWorn)
            {
                lButtons += [llList2String(ATTACH_POINTS, n)];
            }
        }
    }
    g_kAttachID = Dialog(kID, sPrompt, lButtons, [UPMENU], 0);
}

UpdateSettings()
{    //build one big string from the settings list
    //llOwnerSay("TP settings: " + llDumpList2String(g_lSettings, ","));
    integer iSettingsLength = llGetListLength(g_lSettings);
    if (iSettingsLength > 0)
    {
        g_lLockedItems=[];
        g_lLockedAttach=[];
        integer n;
        list lNewList;
        for (n = 0; n < iSettingsLength; n = n + 2)
        {
            list sOption=llParseString2List(llList2String(g_lSettings, n),[":"],[]);
            string sValue=llList2String(g_lSettings, n + 1);
            //Debug(llList2String(g_lSettings, n) + "=" + sValue);
            lNewList += [llList2String(g_lSettings, n) + "=" + llList2String(g_lSettings, n + 1)];
            if (llGetListLength(sOption)==2
                && (llList2String(sOption,0)=="addoutfit"
                    ||llList2String(sOption,0)=="remoutfit")
                && sValue=="n")
                g_lLockedItems += [llList2String(sOption,1)];
            if (llGetListLength(sOption)==1 && llList2String(sOption,0)=="remoutfit" && sValue=="n")
                g_lLockedItems += [ALL];

            if (llGetListLength(sOption)==2
                && (llList2String(sOption,0)=="addattach"
                    || llList2String(sOption,0)=="remattach"
                    || llList2String(sOption,0)=="detach")
                && sValue=="n")
                g_lLockedAttach += [llList2String(sOption,1)];
        }
        //output that string to viewer
        llMessageLinked(LINK_SET, RLV_CMD, llDumpList2String(lNewList, ","), NULL_KEY);
    }
}

ClearSettings()
{   //clear settings list
    g_lSettings = [];
    //clear the list of locked items
    g_lLockedItems = [];
    g_lLockedAttach=[];
    SaveLockAllFlag(0);
    //remove tpsettings from DB
    llMessageLinked(LINK_SET, SETTING_DELETE, g_sDBToken, NULL_KEY);
    //main RLV script will take care of sending @clear to viewer
}

SaveLockAllFlag(integer iSetting)
{
    if (g_iAllLocked == iSetting)
    {
        return;
    }
    g_iAllLocked = iSetting;
    if(iSetting > 0)
    {
        //save the flag to the database
        llMessageLinked(LINK_SET, SETTING_SAVE, g_sDBTokenLockAll+"=Y", NULL_KEY);
    }
    else
    {
        //delete the flag from the database
        llMessageLinked(LINK_SET, SETTING_DELETE, g_sDBTokenLockAll, NULL_KEY);
    }
}

DolockAll(string sCommand, key kID)
{
    if (sCommand == "lockall")      //lock all clothes and attachment points
    {
        //do the actual lockall
        llMessageLinked(LINK_SET, RLV_CMD, "addattach=n", kID);
        llMessageLinked(LINK_SET, RLV_CMD, "remattach=n", kID);
        llMessageLinked(LINK_SET, RLV_CMD,  "remoutfit=n", kID);
        llMessageLinked(LINK_SET, RLV_CMD,  "addoutfit=n", kID);
    }
    else  if (sCommand == "unlockall") //lock all clothes and attachment points
    {
        //remove the lockall
        llMessageLinked(LINK_SET, RLV_CMD, "addattach=y", kID);
        llMessageLinked(LINK_SET, RLV_CMD, "remattach=y", kID);
        llMessageLinked(LINK_SET, RLV_CMD,  "remoutfit=y", kID);
        llMessageLinked(LINK_SET, RLV_CMD,  "addoutfit=y", kID);
    }
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
            if ( llList2String(lParams, 0)== g_sDBTokenLockAll)
            {
                //re-apply the lockall after a re-log
                g_iAllLocked = 1;
                DolockAll("lockall", kID);
            }

            if (llList2String(lParams, 0) == g_sDBToken)
            {
                g_lSettings = llParseString2List(llList2String(lParams, 1), [","], []);
                UpdateSettings();
            }
            else if (llList2String(lParams, 0) == g_sSmartToken)
            {
                g_iSmartStrip=TRUE;
            }            
        }
}
// pragma inline
HandleDIALOG(integer iSender, integer iNum, string sStr, key kID)
{
    if (iNum == DIALOG_RESPONSE)
    {
        list lMenuParams = llParseString2List(sStr, ["|"], []);
        key kAv = (key)llList2String(lMenuParams, 0);
        string sMessage = llList2String(lMenuParams, 1);
        integer iPage = (integer)llList2String(lMenuParams, 2);
        g_kMenuUser = kAv;

        if (llListFindList([g_kMainID, g_kClothID, g_kAttachID, g_kLockID, g_kLockAttachID], [kID]) != -1)
        {//it's one of our menus
            if (kID == g_kMainID)
            {
                if (sMessage == UPMENU)
                {
                    llMessageLinked(LINK_SET, MENU_SUBMENU, g_sParentMenu, kAv);
                }
                else if (sMessage == "Clothing")
                {
                    QueryClothing();
                }
                else if (sMessage == "Attachment")
                {
                    QueryAttachments();
                }
                else if (sMessage == "LockClothing")
                {
                    LockMenu(kAv);
                }
                else if (sMessage == "LockAttachment")
                {
                    LockAttachmentMenu(kAv);
                }
                else if (sMessage == "LockAll")
                {
                    //forward this command to the other section - it came from the menu button
                    g_iRemenu = TRUE;
                    llMessageLinked(LINK_SET, COMMAND_NOAUTH, "lockall", kAv);
                }
                else if (sMessage == "UnLockAll")
                {
                    //forward this command to the other section - it came from the menu button
                    g_iRemenu = TRUE;
                    llMessageLinked(LINK_SET, COMMAND_NOAUTH, "unlockall", kAv);
                }
                else if (sMessage == SMARTON) 
                { 
                    llMessageLinked(LINK_SET, COMMAND_NOAUTH, "smartstrip on", kAv);
                    MainMenu(kAv);
                }
                else if (sMessage == SMARTOFF) 
                { 
                    llMessageLinked(LINK_SET, COMMAND_NOAUTH, "smartstrip off", kAv);                        
                    MainMenu(kAv);
                }
                else if (sMessage == "#RLV Help") 
                { 
                    llGiveInventory(kAv,g_sSmartHelpCard); 
                    MainMenu(kAv);
                }                
                else if (llListFindList(g_lButtons,[sMessage]) != -1)
                {
                    llMessageLinked(LINK_SET, MENU_SUBMENU, sMessage, kAv);
                }
                else
                {
                    //something went horribly wrong.  We got a command that we can't find in the list
                }
            }
            else if (kID == g_kClothID)
            {
                if (sMessage == UPMENU)
                {
                    llMessageLinked(LINK_SET, MENU_SUBMENU, g_sSubMenu, kAv);
                }
                else
                {
                    if (sMessage == ALL)
                    { //send the RLV command to remove it.
                        llMessageLinked(LINK_SET, COMMAND_NOAUTH, "strip all", kAv);
                    }
                    else
                    { //we got a cloth point.
                        //send the RLV command to remove it.
                        llMessageLinked(LINK_SET, COMMAND_NOAUTH, "strip "+sMessage, kAv);
                    }
                    //sleep for a sec to let things detach
                    llSleep(0.5);
                    QueryClothing();
                }
            }
            else if (kID == g_kAttachID)
            {
                if (sMessage == UPMENU)
                {
                    llMessageLinked(LINK_SET, MENU_SUBMENU, g_sSubMenu, kAv);
                }
                else
                {    //we got an attach point.  send a message to detach
                    //send the RLV command to remove it.
                    llMessageLinked(LINK_SET, RLV_CMD,  "detach:" + llToLower(sMessage) + "=force", kAv);
                    //sleep for a sec to let things detach
                    llSleep(0.5);
                    QueryAttachments();
                }
            }
            else if (kID == g_kLockID)
            {
                if (sMessage == UPMENU)
                {
                    llMessageLinked(LINK_SET, MENU_SUBMENU, g_sSubMenu, kAv);
                }
                else
                { 
                    string cstate = llGetSubString(sMessage,0,llStringLength(TICKED) - 1);
                    sMessage=llGetSubString(sMessage,llStringLength(TICKED),-1);
                    if (cstate==UNTICKED)
                    {
                        llMessageLinked(LINK_SET, COMMAND_NOAUTH, "lockclothing "+sMessage, kAv);
                    }
                    else if (cstate==TICKED)
                    {
                        llMessageLinked(LINK_SET, COMMAND_NOAUTH, "unlockclothing "+sMessage, kAv);
                    }
                    g_iRemenu = TRUE;
                }
            }
            else if (kID == g_kLockAttachID)
            {
                if (sMessage == UPMENU)
                {
                    llMessageLinked(LINK_SET, MENU_SUBMENU, g_sSubMenu, kAv);
                }
                else
                { 
                    string cstate = llGetSubString(sMessage,0,llStringLength(TICKED) - 1);
                    sMessage=llGetSubString(sMessage,llStringLength(TICKED),-1);
                    if (cstate==UNTICKED)
                    {
                        llMessageLinked(LINK_SET, COMMAND_NOAUTH, "lockattachment "+sMessage, kAv);
                    }
                    else if (cstate==TICKED)
                    {
                        llMessageLinked(LINK_SET, COMMAND_NOAUTH, "unlockattachment "+sMessage, kAv);
                    }
                    g_iRemenu = TRUE;
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
        if (sStr == g_sSubMenu)
        {
            MainMenu(kID);
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
// pragma inline
HandleCOMMAND(integer iSender, integer iNum, string sStr, key kID)
{
        if (iNum >= COMMAND_OWNER && iNum <= COMMAND_WEARER)
        {   //the command was given by either owner, secowner, group member, or wearer
            list lParams = llParseString2List(sStr, [":", "=", " "], []);
            string sCommand = llList2String(lParams, 0);
            //Debug(sStr + " ## " + sCommand);
            if (sCommand == "smartstrip")
            {
                if(iNum==COMMAND_OWNER || iNum == COMMAND_WEARER)
                {
                    string sOpt=llList2String(lParams,1);
                    if(sOpt == "on")
                    {
                        g_iSmartStrip=TRUE;
                        llMessageLinked(LINK_SET,SETTING_SAVE, g_sSmartToken +"=1",NULL_KEY);                       
                    }
                    else
                    {
                        g_iSmartStrip=FALSE;
                        llMessageLinked(LINK_SET,SETTING_DELETE, g_sSmartToken,NULL_KEY);
                    }
                }
                else Notify(kID,"This requires a properly set-up outfit, only wearer or owner can turn it on.", FALSE);
            }
            else if (sCommand == "strip")
            {
                string sOpt=llList2String(lParams,1);
                if(sOpt=="all")
                {                  
                    if(g_iSmartStrip==TRUE)
                    {
                        integer x=14; //let's not strip tattoos and physics layers;
                        while(x)
                        {
                            if(x==13) 
                                x=9; //skip hair,skin,shape,eyes
                            --x;
                            string sItem=llToLower(llList2String(DETACH_CLOTH_POINTS,x));
                            llMessageLinked(LINK_SET, RLV_CMD, "detachallthis:"+ sItem +"=force",NULL_KEY);
                        }
                    }
                   llMessageLinked(LINK_SET, RLV_CMD,  "remoutfit=force", NULL_KEY);
                }
                sOpt = llToLower(sOpt);
                string test=llToUpper(llGetSubString(sOpt,0,0))+llGetSubString(sOpt,1,-1);
                if(!llListFindList(DETACH_CLOTH_POINTS,[test])==-1)
                {
                    //send the RLV command to remove it.
                    if(g_iSmartStrip==TRUE) 
                        llMessageLinked(LINK_SET, RLV_CMD , "detachallthis:" + sOpt + "=force", NULL_KEY);
                    llMessageLinked(LINK_SET, RLV_CMD,  "remoutfit:" + sOpt + "=force", NULL_KEY); //yes, this isn't an else. We do it in case the item isn't in #RLV.
                }
            }            
            if (llListFindList(g_lRLVcmds, [sCommand]) != -1)
            {    //we've received an RLV command that we control.  only execute if not sub
                if (iNum == COMMAND_WEARER)
                {
                    llOwnerSay("Sorry, but RLV commands may only be given by owner, secowner, or group (if set).");
                }
                else
                {
                    llMessageLinked(LINK_SET, RLV_CMD, sStr, kID);
                    string sOption = llList2String(llParseString2List(sStr, ["="], []), 0);
                    string sParam = llList2String(llParseString2List(sStr, ["="], []), 1);
                    integer iIndex = llListFindList(g_lSettings, [sOption]);
                    string opt1 = llList2String(llParseString2List(sOption, [":"], []), 0);
                    string opt2 = llList2String(llParseString2List(sOption, [":"], []), 1);
                    if (sParam == "n")
                    {
                        if (iIndex == -1)
                        {   //we don't alread have this exact setting.  add it
                            g_lSettings += [sOption, sParam];
                        }
                        else
                        {   //we already have a setting for this option.  update it.
                            g_lSettings = llListReplaceList(g_lSettings, [sOption, sParam], iIndex, iIndex + 1);
                        }
                        llMessageLinked(LINK_SET, SETTING_SAVE, g_sDBToken + "=" + llDumpList2String(g_lSettings, ","), NULL_KEY);
                    }
                    else if (sParam == "y")
                    {
                        if (iIndex != -1)
                        {   //we already have a setting for this option.  remove it.
                            g_lSettings = llDeleteSubList(g_lSettings, iIndex, iIndex + 1);
                        }
                        if (llGetListLength(g_lSettings)>0)
                            llMessageLinked(LINK_SET, SETTING_SAVE, g_sDBToken + "=" + llDumpList2String(g_lSettings, ","), NULL_KEY);
                        else
                            llMessageLinked(LINK_SET, SETTING_DELETE, g_sDBToken, NULL_KEY);
                    }
                    if (g_iRemenu)
                    {
                        g_iRemenu = FALSE;
                        MainMenu(kID);
                    }
                }
            }
            else if (sStr == "lockclothingmenu")
            {
                if (!g_iRLVOn)
                {
                    Notify(kID, "RLV features are now disabled in this collar. You can enable those in RLV submenu. Opening it now.", FALSE);
                    llMessageLinked(LINK_SET, MENU_SUBMENU, "RLV", kID);
                    return;
                }
                g_kMenuUser = kID;
                LockMenu(kID);
            }
            else if (sStr == "lockattachmentmenu")
            {
                if (!g_iRLVOn)
                {
                    Notify(kID, "RLV features are now disabled in this collar. You can enable those in RLV submenu. Opening it now.", FALSE);
                    llMessageLinked(LINK_SET, MENU_SUBMENU, "RLV", kID);
                    return;
                }
                g_kMenuUser = kID;
                LockAttachmentMenu(kID);
            }
            else  if (llGetSubString(sStr, 0, 11) == "lockclothing")            {
                string sMessage = llGetSubString(sStr, 13, -1);
                if (iNum == COMMAND_WEARER)
                {
                    Notify(kID, "Sorry you need owner privileges for locking clothes.", FALSE);
                }
                else if (sMessage==ALL||sStr== "lockclothing")
                {
                    g_lLockedItems += [ALL];
                    Notify(kID, g_sWearerName+"'s clothing has been locked.", TRUE);
                    llMessageLinked(LINK_SET, iNum,  "remoutfit=n", kID);
                    llMessageLinked(LINK_SET, iNum,  "addoutfit=n", kID);
                }
                else if (llListFindList(LOCK_CLOTH_POINTS,[sMessage])!=-1)
                {
                    g_lLockedItems += sMessage;
                    Notify(kID, g_sWearerName+"'s "+sMessage+" has been locked.", TRUE);
                    llMessageLinked(LINK_SET, iNum,  "remoutfit:" + sMessage + "=n", kID);
                    llMessageLinked(LINK_SET, iNum,  "addoutfit:" + sMessage + "=n", kID);
                }
                else Notify(kID, "Sorry you must either specify a cloth name or not use a parameter (which locks all the clothing layers).", FALSE);
                if (g_iRemenu) LockMenu(kID);
            }
            else if (llGetSubString(sStr, 0, 13) == "unlockclothing")
            {
                if (iNum == COMMAND_WEARER)
                {
                    Notify(kID, "Sorry you need owner privileges for unlocking clothes.", FALSE);
                }
                else
                {
                    string sMessage = llGetSubString(sStr, 15, -1);
                    if (sMessage==ALL||sStr=="unlockclothing")
                    {
                        llMessageLinked(LINK_SET, iNum,  "remoutfit=y", kID);
                        llMessageLinked(LINK_SET, iNum,  "addoutfit=y", kID);
                        Notify(kID, g_sWearerName+"'s clothing has been unlocked.", TRUE);
                        integer iIndex = llListFindList(g_lLockedItems,[ALL]);
                        if (iIndex!=-1) g_lLockedItems = llDeleteSubList(g_lLockedItems,iIndex,iIndex);
                    }
                    else
                    {
                        llMessageLinked(LINK_SET, iNum,  "remoutfit:" + sMessage + "=y", kID);
                        llMessageLinked(LINK_SET, iNum,  "addoutfit:" + sMessage + "=y", kID);
                        Notify(kID, g_sWearerName+"'s "+sMessage+" has been unlocked.", TRUE);
                        integer iIndex = llListFindList(g_lLockedItems,[sMessage]);
                        if (iIndex!=-1) g_lLockedItems = llDeleteSubList(g_lLockedItems,iIndex,iIndex);
                    }
                }
                if (g_iRemenu) LockMenu(kID);
            }
            else  if (llGetSubString(sStr, 0, 13) == "lockattachment")
            {
                string sMessage = llGetSubString(sStr, 15, -1);

                if (iNum == COMMAND_WEARER)
                {
                    Notify(kID, "Sorry you need owner privileges for locking attachments.", FALSE);
                    if (g_iRemenu) LockAttachmentMenu(kID);
                }
                else if (llListFindList(ATTACH_POINTS ,[sMessage])!=-1)
                {
                    g_iLastAuth = iNum;
                    QuerySingleAttachment(sMessage);
                }
                else
                {
                    Notify(kID, "Sorry you must either specify a attachment name.", FALSE);
                    if (g_iRemenu) LockAttachmentMenu(kID);
                }
            }
            else  if (sStr == "lockall")      //lock all clothes and attachment points
            {
                if (iNum == COMMAND_WEARER)
                {
                    Notify(kID, "Sorry you need owner privileges for locking attachments.", FALSE);
                }
                else
                {
                    DolockAll(sStr, kID);
                    SaveLockAllFlag(1);
                    Notify(kID, g_sWearerName+"'s clothing and attachments have been locked.", TRUE);
                }
                if (g_iRemenu) MainMenu(kID);   //redraw the menu if the lockall button was pressed
                g_iRemenu = FALSE;
            }
            else  if (sStr == "unlockall") //lock all clothes and attachment points
            {
                if (iNum == COMMAND_WEARER)
                {
                    Notify(kID, "Sorry you need owner privileges for unlocking attachments.", FALSE);
                }
                else
                {
                    DolockAll(sStr, kID);
                    SaveLockAllFlag(0);
                    Notify(kID, g_sWearerName+"'s clothing and attachments have been unlocked.", TRUE);
                }
                if (g_iRemenu) MainMenu(kID);   //redraw the menu if the unlockall button was pressed
                g_iRemenu = FALSE;

            }

            else if (llGetSubString(sStr, 0, 15) == "unlockattachment")
            {
                if (iNum == COMMAND_WEARER)
                {
                    Notify(kID, "Sorry you need owner privileges for unlocking attachments.", FALSE);
                }
                else
                {
                    string sMessage = llGetSubString(sStr, 17, -1);
                {
                    llMessageLinked(LINK_SET, iNum,  "addattach:" + sMessage + "=y", kID);
                    llMessageLinked(LINK_SET, iNum,  "remattach:" + sMessage + "=y", kID);
                    Notify(kID, g_sWearerName+"'s "+sMessage+" has been unlocked.", TRUE);
                    integer iIndex = llListFindList(g_lLockedAttach,[sMessage]);
                    if (iIndex!=-1) g_lLockedAttach = llDeleteSubList(g_lLockedAttach,iIndex,iIndex);
                }
                }
                if (g_iRemenu) LockAttachmentMenu(kID);
            }
            else if (sStr == "refreshmenu")
            {
                g_lButtons = [];
                llMessageLinked(LINK_SET, MENU_REQUEST, g_sSubMenu, NULL_KEY);
            }
            else if (sStr == "undress")
            {
                if (!g_iRLVOn)
                {
                    Notify(kID, "RLV features are now disabled in this collar. You can enable those in RLV submenu. Opening it now.", FALSE);
                    llMessageLinked(LINK_SET, MENU_SUBMENU, "RLV", kID);
                    return;
                }

                MainMenu(kID);
            }
            else if (sStr == "clothing")
            {
                if (!g_iRLVOn)
                {
                    Notify(kID, "RLV features are now disabled in this collar. You can enable those in RLV submenu. Opening it now.", FALSE);
                    llMessageLinked(LINK_SET, MENU_SUBMENU, "RLV", kID);
                    return;
                }
                g_kMenuUser = kID;
                QueryClothing();
            }
            else if (sStr == "attachment")
            {
                if (!g_iRLVOn)
                {
                    Notify(kID, "RLV features are now disabled in this collar. You can enable those in RLV submenu. Opening it now.", FALSE);
                    llMessageLinked(LINK_SET, MENU_SUBMENU, "RLV", kID);
                    return;
                }
                g_kMenuUser = kID;
                QueryAttachments();
            }
        }
        // rlvoff -> we have to turn the menu off too
        else if (iNum>=COMMAND_OWNER && sStr=="rlvoff") g_iRLVOn=FALSE;

}
// pragma inline
HandleRLV(integer iSender, integer iNum, string sStr, key kID)
{
    if (iNum == RLV_OFF) g_iRLVOn=FALSE;
    // rlvon -> we have to turn the menu on again
    else if (iNum == RLV_ON) g_iRLVOn=TRUE;

    else if (iNum == RLV_REFRESH)
    {//rlvmain just started up.  Tell it about our current restrictions
        g_iRLVOn = TRUE;
        if(g_iAllLocked > 0)       //is everything locked?
            DolockAll("lockall", kID);  //lock everything on a RLV_REFRESH

        UpdateSettings();
    }
    else if (iNum == RLV_CLEAR)
    {   //clear db and local settings list
        ClearSettings();
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
        g_sWearerName = llKey2Name(g_kWearer);
        llMessageLinked(LINK_SET, MENU_REQUEST, g_sSubMenu, NULL_KEY);
        llSleep(1.0);
        llMessageLinked(LINK_SET, MENU_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, NULL_KEY);
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
        else if ((iNum >= COMMAND_OWNER) && (iNum <= COMMAND_EVERYONE))
        {
            HandleCOMMAND(iSender,iNum,sStr,kID);
        }
    }    

    listen(integer iChan, string sName, key kID, string sMessage)
    {
        llListenRemove(g_iListener);
        llSetTimerEvent(0.0);
        if (iChan == g_iClothRLV)
        {   //llOwnerSay(sMessage);
            ClothingMenu(g_kMenuUser, sMessage);
        }
        else if (iChan == g_iAttachRLV)
        {
            DetachMenu(g_kMenuUser, sMessage);
        }
        else if (iChan > g_iAttachRLV && iChan <= g_iAttachRLV + llGetListLength(ATTACH_POINTS))
        {
            integer iIndex = iChan - g_iAttachRLV -1;
            string sPoint = llList2String(ATTACH_POINTS, iIndex);
            g_lLockedAttach += [sPoint];
            if ((integer) sMessage)
            {
                Notify(kID, g_sWearerName+"'s "+sPoint+" has been locked in place.", TRUE);
                llMessageLinked(LINK_SET, g_iLastAuth,  "remattach:" + sPoint + "=n", kID);
            }
            else
            {
                Notify(kID, g_sWearerName+"'s "+sPoint+" has been locked empty.", TRUE);
                llMessageLinked(LINK_SET, g_iLastAuth,  "addattach:" + sPoint + "=n", kID);
            }
            if (g_iRemenu) LockAttachmentMenu(g_kMenuUser);
        }
    }

    timer()
    {//stil needed for rlv listen timeouts, though not dialog timeouts anymore
        llListenRemove(g_iListener);
        llSetTimerEvent(0.0);
    }

    on_rez(integer iParam)
    {
        llResetScript();
    }

}