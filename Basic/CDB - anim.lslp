/*--------------------------------------------------------------------------------**
**  File: CDB - anim                                                              **
** ------------------------------------------------------------------------------ **
**  Version: 6.00.001                                                             **
** ------------------------------------------------------------------------------ **
** Licensed under the GPLv2, with the additional requirement that these scripts   **
** remain "full perms" in Second Life®.  See "CollarDB License" for details.      **
** ------------------------------------------------------------------------------ **
** ©2014 CollarDB and Individual Contributors                                     **
**--------------------------------------------------------------------------------*/

//CollarDB - anim - 3.520
//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "CollarDB License" for details.

//needs to handle anim requests from sister scripts as well
//this script as essentially two layers
//lower layer: coordinate animation requests that come in on link messages.  keep a list of playing anims disable AO when needed
//upper layer: use the link message anim api to provide a pose menu

//2009-03-22, Lulu Pink, animlock - issue 367

/*-------------//
//  VARIABLES  //
//-------------*/

list g_lAnims;
//integer g_iNumAnims;//the number of anims that don't start with "~"
//integer g_iPageSize = 8;//number of anims we can fit on one page of a multi-page menu
list g_lPoseList;

//for the height scaling feature
key g_kDataID;
string card = "~heightscalars";
integer g_iLine = 0;
list g_lAnimScalars;//a 3-strided list in form animname,scalar,delay
integer g_iAdjustment = 0;

string g_sCurrentPose = "";
integer g_iLastRank = 0; //in this integer, save the rank of the person who posed the av, according to message map.  0 means unposed
string g_sParentMenu = "Main";
string g_sAnimMenu = "Animations";
string g_sSubMenu = g_sAnimMenu;
string g_sPoseMenu = "Pose";
string g_sAOMenu = "AO";
string g_sGiveAO = "Give AO";
string g_sTriggerAO = "AO Menu";
list g_lAnimButtons = ["Pose", g_sTriggerAO, g_sGiveAO, "AO ON", "AO OFF"];
//added for sAnimlock
string TICKED = "(*)";
string UNTICKED = "( )";
string ANIMLOCK = "AnimLock";
string RELEASE = "*Release*";
integer g_iAnimLock = FALSE;
string g_sLockToken = "animlock";

string g_sSETTING_Url = "http://data.collardb.com/"; //defaul OC url, can be changed in defaultsettings notecard and wil be send by settings script if changed

string g_sAnimToken = "currentpose";

//string UPMENU = "?";
//string MORE = "?";
string MORE = ">";
//string PREV = "<";

//integer iPage = 0;
//integer g_sAnimMenuchannel = 2348207;
//integer g_sPoseMenuchannel = 2348208;
//integer g_sAOMenuchannel = 2348209;
//integer g_iTimeOut = 60;
//integer g_iListener;
integer g_iAOChannel = -782690;
integer g_iInterfaceChannel = -12587429;
string AO_ON = "ZHAO_STANDON";
string AO_OFF = "ZHAO_STANDOFF";
string AO_MENU = "ZHAO_MENU";

list g_lMenuIDs;//three strided list of avkey, dialogid, and menuname
integer g_iMenuStride = 3;

string ANIMMENU = "Anim";
string AOMENU = "AO";
string POSEMENU = "Pose";

string HEIGHTFIX = "HeightFix";
string g_sHeightFixToken = "HFix";
integer g_iHeightFix = TRUE;


$import lib.MessageMap.lslm ();
$import lib.CommonVariables.lslm ();
$import lib.CommonFunctions.lslm ();



/*---------------//
//  FUNCTIONS    //
//---------------*/

AnimMenu(key kID)
{
    string sPrompt = "Choose an option.\n";
    list lButtons;
    if(g_iAnimLock)
    {
        sPrompt += TICKED + ANIMLOCK + " is an Owner only option.\n";
        sPrompt += "Owner issued animations/poses are locked and only the Owner can release the sub now.";
        lButtons = [TICKED + ANIMLOCK];
    }
    else
    {
        sPrompt += UNTICKED + ANIMLOCK + " is an Owner only option.\n";
        sPrompt += "The sub is free to self-release or change poses as well as any secowner.";
        lButtons = [UNTICKED + ANIMLOCK];
    }
    if(g_iHeightFix)
    {
        sPrompt += "\nThe height of some poses will be adjusted now.";
        lButtons += [TICKED + HEIGHTFIX];
    }
    else
    {
        sPrompt += "\nThe height of the poses will not be changed.";
        lButtons += [UNTICKED + HEIGHTFIX];
    }
    sPrompt += "\nATTENTION!!!!!!\nYou need the CollarDB Sub AO 2.6 or higher to work with this collar menu!";
    lButtons += llListSort(g_lAnimButtons, 1, TRUE);
    key kMenuID = Dialog(kID, sPrompt, lButtons, [UPMENU], 0);
    list lNewStride = [kID, kMenuID, ANIMMENU];
    integer iIndex = llListFindList(g_lMenuIDs, [kID]);
    if (iIndex == -1)
    {
        g_lMenuIDs += lNewStride;
    }
    else
    {//this person is already in the dialog list.  replace their entry
        g_lMenuIDs = llListReplaceList(g_lMenuIDs, lNewStride, iIndex, iIndex - 1 + g_iMenuStride);
    }
}

AOMenu(key kID)
{
    string sPrompt = "Choose an option.";

}

PoseMenu(key kID, integer iPage)
{ //create a list
    string sPrompt = "Choose an anim to play.";
    key kMenuID = Dialog(kID, sPrompt, g_lPoseList, [RELEASE, UPMENU], iPage);
    list lNewStride = [kID, kMenuID, POSEMENU];
    integer iIndex = llListFindList(g_lMenuIDs, [kID]);
    if (iIndex == -1)
    {
        g_lMenuIDs += lNewStride;
    }
    else
    {//this person is already in the dialog list.  replace their entry
        g_lMenuIDs = llListReplaceList(g_lMenuIDs, lNewStride, iIndex, iIndex - 1 + g_iMenuStride);
    }
}

RefreshAnim()
{ //g_lAnims can get lost on TP, so re-play g_lAnims[0] here, and call this function in "changed" event on TP
    if (llGetListLength(g_lAnims))
    {
        if (llGetPermissions() & PERMISSION_TRIGGER_ANIMATION)
        {
            string sAnim = llList2String(g_lAnims, 0);
            if (llGetInventoryType(sAnim) == INVENTORY_ANIMATION)
            { //get and stop currently playing anim
                StartAnim(sAnim);
                /*
                    if (llGetListLength(g_lAnims))
                    {
                        string s_Current = llList2String(g_lAnims, 0);
                        llStopAnimation(s_Current);
                    }
                //add anim to list
                g_lAnims = [sAnim] + g_lAnims;//this way, g_lAnims[0] is always the currently playing anim
                llStartAnimation(sAnim);
                llSay(g_iInterfaceChannel, AO_OFF);
                */
                }
            else
            {
                //Popup(g_kWearer, "Error: Couldn't find anim: " + sAnim);
            }
        }
        else
        {
            Notify(g_kWearer, "Error: Somehow I lost permission to animate you.  Try taking me off and re-attaching me.", FALSE);
        }
    }
}

StartAnim(string sAnim)
{
    if (llGetPermissions() & PERMISSION_TRIGGER_ANIMATION)
    {
        if (llGetInventoryType(sAnim) == INVENTORY_ANIMATION)
        {   //get and stop currently playing anim
            if (llGetListLength(g_lAnims))
            {
                string s_Current = llList2String(g_lAnims, 0);
                llStopAnimation(s_Current);
            }

            //stop any currently playing height adjustment
            if (g_iAdjustment)
            {
                llStopAnimation("~" + (string)g_iAdjustment);
                g_iAdjustment = 0;
            }

            //add anim to list
            g_lAnims = [sAnim] + g_lAnims;//this way, g_lAnims[0] is always the currently playing anim
            llStartAnimation(sAnim);
            llWhisper(g_iInterfaceChannel, "CollarComand|499|" + AO_OFF);
            llWhisper(g_iAOChannel, AO_OFF);

            if (g_iHeightFix)
            {
                //adjust height for anims in g_lAnimScalars
                integer iIndex = llListFindList(g_lAnimScalars, [sAnim]);
                if (iIndex != -1)
                {//we just started playing an anim in our g_iAdjustment list
                    //pause to give certain anims time to ease in
                    llSleep((float)llList2String(g_lAnimScalars, iIndex + 2));
                    vector vAvScale = llGetAgentSize(g_kWearer);
                    float fScalar = (float)llList2String(g_lAnimScalars, iIndex + 1);
                    g_iAdjustment = llRound(vAvScale.z * fScalar);
                    if (g_iAdjustment > -30)
                    {
                        g_iAdjustment = -30;
                    }
                    else if (g_iAdjustment < -50)
                    {
                        g_iAdjustment = -50;
                    }
                    llStartAnimation("~" + (string)g_iAdjustment);
                }
            }
        }
        else
        {
            //Popup(g_kWearer, "Error: Couldn't find anim: " + sAnim);
        }
    }
    else
    {
        Notify(g_kWearer, "Error: Somehow I lost permission to animate you.  Try taking me off and re-attaching me.", FALSE);
    }
}

StopAnim(string sAnim)
{
    if (llGetPermissions() & PERMISSION_TRIGGER_ANIMATION)
    {
        if (llGetInventoryType(sAnim) == INVENTORY_ANIMATION)
        {   //remove all instances of anim from anims
            //loop from top to avoid skipping
            integer n;
            for (n = llGetListLength(g_lAnims) - 1; n >= 0; n--)
            {
                if (llList2String(g_lAnims, n) == sAnim)
                {
                    g_lAnims = llDeleteSubList(g_lAnims, n, n);
                }
            }
            llStopAnimation(sAnim);

            //stop any currently-playing height adjustment
            if (g_iAdjustment)
            {
                llStopAnimation("~" + (string)g_iAdjustment);
                g_iAdjustment = 0;
            }
            //play the new g_lAnims[0]
            //if anim list is empty, turn AO back on
            if (llGetListLength(g_lAnims))
            {
                string sNewAnim = llList2String(g_lAnims, 0);
                llStartAnimation(sNewAnim);

                //adjust height for anims in g_lAnimScalars
                integer iIndex = llListFindList(g_lAnimScalars, [sNewAnim]);
                if (iIndex != -1)
                {//we just started playing an anim in our adjustment list
                    //pause to give certain anims time to ease in
                    llSleep((float)llList2String(g_lAnimScalars, iIndex + 2));
                    vector vAvScale = llGetAgentSize(g_kWearer);
                    float fScalar = (float)llList2String(g_lAnimScalars, iIndex + 1);
                    g_iAdjustment = llRound(vAvScale.z * fScalar);
                    if (g_iAdjustment > -30)
                    {
                        g_iAdjustment = -30;
                    }
                    else if (g_iAdjustment < -50)
                    {
                        g_iAdjustment = -50;
                    }
                    llStartAnimation("~" + (string)g_iAdjustment);
                }
            }
            else
            {
                llWhisper(g_iInterfaceChannel, "CollarComand|499|" + AO_ON);
                llWhisper(g_iAOChannel, AO_ON);
            }
        }
        else
        {
            //Popup(g_kWearer, "Error: Couldn't find anim: " + sAnim);
        }
    }
    else
    {
        Notify(g_kWearer, "Error: Somehow I lost permission to animate you.  Try taking me off and re-attaching me.", FALSE);
    }
}

DeliverAO(key kID)
{
    string sName = "CollarDB Sub AO";
    string sVersion = "0.0";

    string sUrl = g_sSETTING_Url + "updater/check?";
    sUrl += "object=" + llEscapeURL(sName);
    sUrl += "&version=" + llEscapeURL(sVersion);
    llHTTPRequest(sUrl, [HTTP_METHOD, "GET",HTTP_MIMETYPE,"text/plain;charset=utf-8"], "");
    Notify(kID, "Queuing delivery of " + sName + ".  It should be delivered in about 30 seconds.", FALSE);
}

RequestPerms()
{
    if (llGetAttached())
    {
        llRequestPermissions(g_kWearer, PERMISSION_TRIGGER_ANIMATION);
    }
}


CreateAnimList()
{
    g_lPoseList=[];
    integer iMax = llGetInventoryNumber(INVENTORY_ANIMATION);
    integer i;
    string sName;
    for (i=0;i<iMax;i++)
    {
        sName=llGetInventoryName(INVENTORY_ANIMATION, i);

        if (sName != "" && llGetSubString(sName, 0, 0) != "~")
        {
            g_lPoseList+=[sName];
        }
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
        string sToken = llList2String(lParams, 0);
        string sValue = llList2String(lParams, 1);
        if (sToken == g_sLockToken)
        {
            if(llList2String(lParams, 1) == "1")
            {
                g_iAnimLock = TRUE;
            }
        }
        else if (sToken == "HTTPDB")
        {
            g_sSETTING_Url = sValue;
        }
        else if (sToken == g_sHeightFixToken)
        {
            g_iHeightFix = (integer)sValue;
        }
    }
}
// pragma inline
HandleLOCALSETTING(integer iSender, integer iNum, string sStr, key kID)
{
    if (iNum == SETTING_RESPONSE)
    {
        list lParams = llParseString2List(sStr, ["="], []);
        string sToken = llList2String(lParams, 0);
        list sAnimParams = llParseString2List(llList2String(lParams, 1), [","], []);
        if (sToken == g_sAnimToken)
        {
            //
            g_sCurrentPose = llList2String(sAnimParams, 0);
            g_iLastRank = (integer)llList2String(sAnimParams, 1);
            llMessageLinked(LINK_SET, ANIM_START, g_sCurrentPose, NULL_KEY);
        }
    }
}
// pragma inline
HandleDIALOG(integer iSender, integer iNum, string sStr, key kID)
{
    if (iNum == DIALOG_RESPONSE)
    {
        integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
        if (iMenuIndex != -1)
        {
            //got a menu response meant for us.  pull out values
            list lMenuParams = llParseString2List(sStr, ["|"], []);
            key kAv = (key)llList2String(lMenuParams, 0);
            string sMessage = llList2String(lMenuParams, 1);
            integer iPage = (integer)llList2String(lMenuParams, 2);
            string sMenuType = llList2String(g_lMenuIDs, iMenuIndex + 1);
            //remove stride from g_lMenuIDs
            //we have to subtract from the index because the dialog id comes in the middle of the stride
            g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex - 2 + g_iMenuStride);

            if (sMenuType == ANIMMENU)
            {
                if (sMessage == UPMENU)
                {
                    llMessageLinked(LINK_SET, MENU_SUBMENU, g_sParentMenu, kAv);
                }
                else if (sMessage == "Pose")
                {
                    PoseMenu(kAv, 0);
                }
                else if (sMessage == g_sTriggerAO)
                {
                    llMessageLinked(LINK_SET, COMMAND_NOAUTH, "ao menu", kAv);
                    //llSay(g_iInterfaceChannel, AO_MENU + "|" + (string)kID);
                    Notify(kAv, "Attempting to trigger the AO menu.  This will only work if " + llKey2Name(g_kWearer) + " is wearing the CollarDB Sub AO.", FALSE);
                    //                llMessageLinked(LINK_SET, COMMAND_NOAUTH, "triggerao", kID);
                }
                else if (sMessage == g_sGiveAO)
                {    //queue a delivery
                    DeliverAO(kAv);
                    AOMenu(kAv);
                }
                else if(sMessage == "AO ON")
                {
                    llMessageLinked(LINK_SET, COMMAND_NOAUTH, "ao on", kAv);
                    //llSay(g_iInterfaceChannel, "ZHAO_AOON" + "|" + (string)kID);
                    AOMenu(kAv);
                }
                else if(sMessage == "AO OFF" )
                {
                    llMessageLinked(LINK_SET, COMMAND_NOAUTH, "ao off", kAv);
                    //llSay(g_iInterfaceChannel, "ZHAO_AOOFF" + "|" + (string)kID);
                    AOMenu(kAv);
                }
                else if(llGetSubString(sMessage, llStringLength(TICKED), -1) == ANIMLOCK)
                {
                    llMessageLinked(LINK_SET,COMMAND_NOAUTH, sMessage, kAv);
                }
                else if(llGetSubString(sMessage, llStringLength(TICKED), -1) == HEIGHTFIX)
                {
                    llMessageLinked(LINK_SET,COMMAND_NOAUTH, sMessage, kAv);
                }
                else if (~llListFindList(g_lAnimButtons, [sMessage]))
                {
                    llMessageLinked(LINK_SET, MENU_SUBMENU, sMessage, kAv);
                }
            }
            else if (sMenuType == POSEMENU)
            {
                if (sMessage == UPMENU)
                { //return on parent menu, so the animmenu below doesn't come up
                    llMessageLinked(LINK_SET, MENU_SUBMENU, g_sAnimMenu, kAv);
                    return;
                }
                else if (sMessage == "*Release*")
                {
                    llMessageLinked(LINK_SET, COMMAND_NOAUTH, "release", kAv);
                }
                else  //we got an animation name
                    //if ((integer)sMessage)
                { //we don't know any more what the speaker's auth is, so pass the command back through the auth system.  then it will play only if authed
                    //string sAnimsName = llGetInventoryName(INVENTORY_ANIMATION, (integer)sMessage - 1);
                    llMessageLinked(LINK_SET, COMMAND_NOAUTH, sMessage, kAv);
                }
                PoseMenu(kAv, iPage);
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
            AnimMenu(kID);
        }
        else if (sStr == g_sPoseMenu)
        {//we don't know the authority of the menu requester, so send a message through the auth system
            llMessageLinked(LINK_SET, COMMAND_NOAUTH, "pose", kID);
        }
        else if (sStr == g_sAOMenu)
        {   //give menu
            AOMenu(kID);
        }
        else if (sStr == g_sAnimMenu)
        {   //give menu
            AnimMenu(kID);
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
            if (llListFindList(g_lAnimButtons, [button]) == -1)
            {
                g_lAnimButtons = llListSort(g_lAnimButtons + [button], 1, TRUE);
            }
        }
    }
}
// pragma inline
HandleCOMMAND(integer iSender, integer iNum, string sStr, key kID)
{
    if ((iNum >= COMMAND_OWNER && iNum <= COMMAND_WEARER) || iNum == COMMAND_WEARERLOCKEDOUT)
    {
        list lParams = llParseString2List(sStr, [" "], []);
        string sCommand = llToLower(llList2String(lParams, 0));
        string sValue = llToLower(llList2String(lParams, 1));
        if (sStr == "release")
        { //only release if person giving command outranks person who posed us
            if ((iNum <= g_iLastRank) || !g_iAnimLock)
            {
                g_iLastRank = iNum;
                llMessageLinked(LINK_SET, ANIM_STOP, g_sCurrentPose, NULL_KEY);
                g_sCurrentPose = "";
                llMessageLinked(LINK_SET, SETTING_DELETE, g_sAnimToken, "");
            }
        }
        else if (sStr == "animations")
        {   //give menu
            AnimMenu(kID);
        }
        else if (sStr == "settings")
        {
            if (g_sCurrentPose != "")
            {
                Notify(kID, "Current Pose: " + g_sCurrentPose, FALSE);
            }
        }
        else if ((sStr == "runaway" || sStr == "reset") && (iNum == COMMAND_OWNER || iNum == COMMAND_WEARER))
        {   //stop pose
            if (g_sCurrentPose != "")
            {
                StopAnim(g_sCurrentPose);
            }
            llMessageLinked(LINK_SET, SETTING_DELETE, g_sAnimToken, "");
            llResetScript();
        }
        else if (sStr == "pose")
        {  //do multi page menu listing anims
            PoseMenu(kID, 0);
        }
        //added for anim lock
        else if((llGetSubString(sStr, llStringLength(TICKED), -1) == ANIMLOCK) && (iNum == COMMAND_OWNER))
        {
            integer iIndex = llListFindList(g_lAnimButtons, [sStr]);
            if(llGetSubString(sStr, 0, llStringLength(TICKED) - 1) == TICKED)
            {
                g_iAnimLock = FALSE;
                llMessageLinked(LINK_SET, SETTING_DELETE, g_sLockToken, NULL_KEY);
                // g_lAnimButtons = llListReplaceList(g_lAnimButtons, [UNTICKED + ANIMLOCK], iIndex, iIndex);
                Notify(g_kWearer, "You are now able to self-release animations/poses set by owners or secowner.", FALSE);
                if(kID != g_kWearer)
                {
                    Notify(kID, llKey2Name(g_kWearer) + " is able to self-release animations/poses set by owners or secowner.", FALSE);
                }
            }
            else
            {
                g_iAnimLock = TRUE;
                llMessageLinked(LINK_SET, SETTING_SAVE, g_sLockToken + "=1", NULL_KEY);
                // g_lAnimButtons = llListReplaceList(g_lAnimButtons, [TICKED + ANIMLOCK], iIndex, iIndex);
                Notify(g_kWearer, "You are now locked into animations/poses set by owners or secowner.", FALSE);
                if(kID != g_kWearer)
                {
                    Notify(kID, llKey2Name(g_kWearer) + " is now locked into animations/poses set by owners or secowner.", FALSE);
                }
            }
            AnimMenu(kID);
        }
        else if((sCommand == llToLower(ANIMLOCK)) && (iNum == COMMAND_OWNER))
        {
            if(sValue == "on" && !g_iAnimLock)
            {
                integer iIndex = llListFindList(g_lAnimButtons, [UNTICKED + ANIMLOCK]);
                g_iAnimLock = TRUE;
                llMessageLinked(LINK_SET, SETTING_SAVE, g_sLockToken + "=1", NULL_KEY);
                g_lAnimButtons = llListReplaceList(g_lAnimButtons, [TICKED + ANIMLOCK], iIndex, iIndex);
                Notify(g_kWearer, "You are now locked into animations your owner or secowner issues.", FALSE);
                if(kID != g_kWearer)
                {
                    Notify(kID, llKey2Name(g_kWearer) + " is now locked in animations/poses set by owners or secowner and cannot self-release.", FALSE);
                }
            }
            else if(sValue == "off" && g_iAnimLock)
            {
                integer iIndex = llListFindList(g_lAnimButtons, [TICKED + ANIMLOCK]);
                g_iAnimLock = FALSE;
                llMessageLinked(LINK_SET, SETTING_DELETE, g_sLockToken, NULL_KEY);
                g_lAnimButtons = llListReplaceList(g_lAnimButtons, [UNTICKED + ANIMLOCK], iIndex, iIndex);
                Notify(g_kWearer,"You are able to release all animations by yourself.", FALSE);
                if(kID != g_kWearer)
                {
                    Notify(kID, llKey2Name(g_kWearer) + " is able to self-release animations/poses set by owners or secowner.", FALSE);
                }
            }
        }
        else if(llGetSubString(sStr, llStringLength(TICKED), -1) == HEIGHTFIX)
        {
            if ((iNum == COMMAND_OWNER)||(kID == g_kWearer))
            {
                if(llGetSubString(sStr, 0, llStringLength(TICKED) - 1) == TICKED)
                {
                    g_iHeightFix = FALSE;
                    llMessageLinked(LINK_SET, SETTING_SAVE, g_sHeightFixToken + "=0", NULL_KEY);
                }
                else
                {
                    g_iHeightFix = TRUE;
                    llMessageLinked(LINK_SET, SETTING_DELETE, g_sHeightFixToken, NULL_KEY);

                }
                if (g_sCurrentPose != "")
                {
                    string sTemp = g_sCurrentPose;
                    StopAnim(sTemp);
                    StartAnim(sTemp);
                }
                AnimMenu(kID);
            }
            else
            {
                Notify(kID,"Only owners or the wearer itself can use this option.",FALSE);
            }
        }
        else if(sCommand == "ao")
        {
            if(sValue == "")
            {
                AOMenu(kID);
            }
            else if(sValue == "off")
            {
                llWhisper(g_iInterfaceChannel, "CollarCommand|" + (string)iNum + "|ZHAO_AOOFF" + "|" + (string)kID);
                llWhisper(g_iAOChannel,"ZHAO_AOOFF");
            }
            else if(sValue == "on")
            {
                llWhisper(g_iInterfaceChannel, "CollarCommand|" + (string)iNum + "|ZHAO_AOON" + "|" + (string)kID);
                llWhisper(g_iAOChannel,"ZHAO_AOON");
            }
            else if(sValue == "menu")
            {
                llWhisper(g_iInterfaceChannel, "CollarCommand|" + (string)iNum + "|" + AO_MENU + "|" + (string)kID);
                llWhisper(g_iAOChannel, AO_MENU + "|" + (string)kID);
            }
            else if (sValue == "lock")
            {
                llWhisper(g_iInterfaceChannel, "CollarCommand|" + (string)iNum + "|ZHAO_LOCK"  + "|" + (string)kID);
            }
            else if (sValue == "unlock")
            {
                llWhisper(g_iInterfaceChannel, "CollarCommand|" + (string)iNum + "|ZHAO_UNLOCK"  + "|" + (string)kID);
            }
            else if(sValue == "hide")
            {
                llWhisper(g_iInterfaceChannel, "CollarCommand|" + (string)iNum + "|ZHAO_AOHIDE" + "|" + (string)kID);
            }
            else if(sValue == "show")
            {
                llWhisper(g_iInterfaceChannel, "CollarCommand|" + (string)iNum + "|ZHAO_AOSHOW" + "|" + (string)kID);
            }
        }
        else if (llGetInventoryType(sStr) == INVENTORY_ANIMATION)
        {
            if (g_sCurrentPose == "")
            {
                g_sCurrentPose = sStr;
                //not currently in a pose.  play one
                g_iLastRank = iNum;
                //StartAnim(sStr);
                llMessageLinked(LINK_SET, ANIM_START, g_sCurrentPose, NULL_KEY);
                llMessageLinked(LINK_SET, SETTING_SAVE, g_sAnimToken + "=" + g_sCurrentPose + "," + (string)g_iLastRank, "");
            }
            else
            {  //only change if command rank is same or higher (lower integer) than that of person who posed us
                if ((iNum <= g_iLastRank) || !g_iAnimLock)
                {
                    g_iLastRank = iNum;
                    llMessageLinked(LINK_SET, ANIM_STOP, g_sCurrentPose, NULL_KEY);
                    g_sCurrentPose = sStr;
                    llMessageLinked(LINK_SET, ANIM_START, g_sCurrentPose, NULL_KEY);
                    llMessageLinked(LINK_SET, SETTING_SAVE, g_sAnimToken + "=" + g_sCurrentPose + "," + (string)g_iLastRank, "");
                }
            }
        }
    }
    else if (iNum == COMMAND_SAFEWORD)
    { // saefword command recieved, release animation
        if(llGetInventoryType(g_sCurrentPose) == INVENTORY_ANIMATION)
        {
            llMessageLinked(LINK_SET, ANIM_STOP, g_sCurrentPose, NULL_KEY);
            g_iAnimLock = FALSE;
            llMessageLinked(LINK_SET, SETTING_DELETE, g_sLockToken, NULL_KEY);
            g_sCurrentPose = "";
        }
    }
}


/*---------------//
//  MAIN CODE    //
//---------------*/
default
{
    on_rez(integer iNum)
    {
        llResetScript();
    }
    state_entry()
    {
        g_kWearer = llGetOwner();
        g_iInterfaceChannel = (integer)("0x" + llGetSubString(g_kWearer,30,-1));
        if (g_iInterfaceChannel > 0) g_iInterfaceChannel = -g_iInterfaceChannel;
        RequestPerms();

        CreateAnimList();

        llMessageLinked(LINK_SET, MENU_REQUEST, g_sAnimMenu, NULL_KEY);
        //llMessageLinked(LINK_SET, MENU_RESPONSE, g_sParentMenu + "|" + g_sAnimMenu, NULL_KEY);

        //start reading the ~heightscalars notecard
        g_kDataID = llGetNotecardLine(card, g_iLine);
    }

    dataserver(key kID, string sData)
    {
        if (kID == g_kDataID)
        {
            if (sData != EOF)
            {
                g_lAnimScalars += llParseString2List(sData, ["|"], []);
                g_iLine++;
                g_kDataID = llGetNotecardLine(card, g_iLine);
            }
        }
    }

    changed(integer iChange)
    {
        if (iChange & CHANGED_TELEPORT)
        {
            RefreshAnim();
        }

        if (iChange & CHANGED_INVENTORY)
        {
            CreateAnimList();
            g_lAnimScalars = [];
            //start re-reading the ~heightscalars notecard
            g_iLine = 0;
            g_kDataID = llGetNotecardLine(card, g_iLine);
        }
    }

    attach(key kID)
    {
        if (kID == NULL_KEY)
        {
            Debug("detached");
            //we were just detached.  clear the anim list and tell the ao to play stands again.
            llWhisper(g_iInterfaceChannel, "499|" + AO_ON);
            llWhisper(g_iAOChannel, AO_ON);
            g_lAnims = [];
        }
    }

    
    link_message(integer iSender, integer iNum, string sStr, key kID)
    {
        if ((iNum >= SETTING_SAVE) && (iNum <= SETTING_REQUEST_NOCACHE))
        {
            HandleHTTPDB(iSender,iNum,sStr,kID);
        }
        else if ((iNum >= SETTING_SAVE) && (iNum <= SETTING_EMPTY))
        {
            HandleLOCALSETTING(iSender,iNum,sStr,kID);
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
        else if (iNum == ANIM_START)
        {
            StartAnim(sStr);
        }
        else if (iNum == ANIM_STOP)
        {
            StopAnim(sStr);
        }        
    }      
}