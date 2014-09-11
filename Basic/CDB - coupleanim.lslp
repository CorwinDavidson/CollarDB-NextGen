/*--------------------------------------------------------------------------------**
**  File: CDB - coupleanim                                                        **
** ------------------------------------------------------------------------------ **
**  Version: 6.00.001                                                             **
** ------------------------------------------------------------------------------ **
** Licensed under the GPLv2, with the additional requirement that these scripts   **
** remain "full perms" in Second Life®.  See "CollarDB License" for details.      **
** ------------------------------------------------------------------------------ **
** ©2014 CollarDB and Individual Contributors                                     **
**--------------------------------------------------------------------------------*/

//coupleanim1
/*-------------//
//  VARIABLES  //
//-------------*/

integer g_iDebug = FALSE;

integer g_iReady = FALSE;

string g_sStopString = "stop";
integer g_iStopChan = 99;
integer g_iListener;
float g_iPermissionTimeout = 30;    //time for the potential kissee to respond before we give up
integer g_iMenuTimeOut = 60;
float g_iAnimTimeOut = 20;    //duration of anim
list g_lTimeouts = [];  // Strided list of timeouts in the form of "unixtime","Timer Type".

list g_lPartners;

key g_kWearer;


string g_sParentMenu = "Animations";
string g_sSubMenu = "Couples";

string UPMENU = "^";
//string MORE = ">";
key g_kAnimmenu;
key g_kPart;
string g_sSensorMode;   //will be set to "chat" or "menu" later


string STOP_COUPLES = "Stop";
string TIME_COUPLES = "Time";

integer g_iLine;
key g_kDataID;
string CARD1 = "coupleanims";
string CARD2 = "coupleanims_personal";
string g_sNoteCard2Read;

list g_lAnimCmds;       //1-strided list of strings that will trigger
list g_lAnimSettings;   //4-strided list of subAnim|domAnim|offset|text, running parallel to g_lAnimCmds,
//such that g_lAnimCmds[0] corresponds to g_lAnimSettings[0:3], and g_lAnimCmds[1] corresponds to g_lAnimSettings[4:7], etc

key g_kCardID1;     //used to detect whether coupleanims card has changed
key g_kCardID2;
float g_fRange = 10.0;  //only scan within this range for anim partners

vector UNIT_VECTOR = <1.0, 0.0, 0.0>;
float g_fWalkingDistance = 1.0; // How close to try to get to the target point while walking, in meters
float g_fWalkingTau = 1.5; // how hard to push me toward partner while walking
float g_fAlignTau = 0.05; // how hard to push me toward partner while aligning
float g_fAlignDelay = 0.6; // how long to let allignment settle (in seconds)

key g_kCmdGiver;
integer g_iCmdIndex;
string g_sTmpName;
key g_kPartner;
string g_sPartnerName;

//i dont think this flag is needed at all
integer g_iTargetID; // remember the walk target to delete
string g_sDBToken = "coupletime";
string g_sSubAnim;
string g_sDomAnim;


/*---------------//
//  MESSAGE MAP  //
//---------------*/
integer COMMAND_NOAUTH          = 0xCDB000;
integer COMMAND_OWNER           = 0xCDB500;
integer COMMAND_SECOWNER        = 0xCDB501;
integer COMMAND_GROUP           = 0xCDB502;
integer COMMAND_WEARER          = 0xCDB503;
integer COMMAND_EVERYONE        = 0xCDB504;
integer COMMAND_OBJECT          = 0xCDB506;
integer COMMAND_RLV_RELAY       = 0xCDB507;

integer POPUP_HELP              = -0xCDB001;      

integer HTTPDB_SAVE             = 0xCDB200;     // scripts send messages on this channel to have settings saved to httpdb
                                                // str must be in form of "token=value"
integer HTTPDB_REQUEST          = 0xCDB201;     // when startup, scripts send requests for settings on this channel
integer HTTPDB_RESPONSE         = 0xCDB202;     // the httpdb script will send responses on this channel
integer HTTPDB_DELETE           = 0xCDB203;     // delete token from DB
integer HTTPDB_EMPTY            = 0xCDB204;     // sent by httpdb script when a token has no value in the db

integer MENUNAME_REQUEST        = 0xCDB300;
integer MENUNAME_RESPONSE       = 0xCDB301;
integer SUBMENU                 = 0xCDB302;
integer MENUNAME_REMOVE         = 0xCDB303;

integer RLV_CMD                 = 0xCDB600;
integer RLV_REFRESH             = 0xCDB601;     // RLV plugins should reinstate their restrictions upon receiving this message.
integer RLV_CLEAR               = 0xCDB602;     // RLV plugins should clear their restriction lists upon receiving this message.

integer ANIM_START              = 0xCDB700;     // send this with the name of an anim in the string part of the message to play the anim
integer ANIM_STOP               = 0xCDB701;     // send this with the name of an anim in the string part of the message to stop the anim
integer CPLANIM_PERMREQUEST     = 0xCDB702;     // id should be av's key, str should be cmd name "hug", "kiss", etc
integer CPLANIM_PERMRESPONSE    = 0xCDB703;     // str should be "1" for got perms or "0" for not.  id should be av's key
integer CPLANIM_START           = 0xCDB704;     // str should be valid anim name.  id should be av
integer CPLANIM_STOP            = 0xCDB705;     // str should be valid anim name.  id should be av

integer DIALOG                  = -0xCDB900;
integer DIALOG_RESPONSE         = -0xCDB901;
integer DIALOG_TIMEOUT          = -0xCDB902;


/*---------------//
//  FUNCTIONS    //
//---------------*/
Debug (string sStr)
{
    if (g_iDebug){
        llOwnerSay(llGetScriptName() + ": " + sStr);
    }
}

Notify(key kID, string sMsg, integer iAlsoNotifyWearer) 
{
    if (kID == g_kWearer) 
    {
        llOwnerSay(sMsg);
    } 
    else 
    {
        llInstantMessage(kID,sMsg);
        if (iAlsoNotifyWearer) 
        {
            llOwnerSay(sMsg);
        }
    }
}

key Dialog(key kRCPT, string sPrompt, list lChoices, list lUtilityButtons, integer iPage)
{
    key kID = llGenerateKey();
    llMessageLinked(LINK_SET, DIALOG, (string)kRCPT + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`"), kID);
    return kID;
}


PartnerMenu(key kID, list kAvs)
{
    string sPrompt = "Pick a partner.";
    g_kPart=Dialog(kID, sPrompt, kAvs, [UPMENU],0);
}

CoupleAnimMenu(key kID)
{
    string sPrompt = "Pick an animation to play.";
    list lButtons = g_lAnimCmds;//we're limiting this to 9 couple anims then
    lButtons += [TIME_COUPLES, STOP_COUPLES];
    g_kAnimmenu=Dialog(kID, sPrompt, lButtons, [UPMENU],0);
}

TimerMenu(key kID)
{
    string sPrompt = "Pick an time to play.";
    list lButtons = ["10", "20", "30"];
    lButtons += ["40", "50", "60"];
    lButtons += ["90", "120", "endless"];
    g_kPart=Dialog(kID, sPrompt, lButtons, [UPMENU],0);
}


integer AnimExists(string sAnim)
{
    return llGetInventoryType(sAnim) == INVENTORY_ANIMATION;
}

integer ValidLine(list lParams)
{
    //valid if length = 4 or 5 (since text is optional) and anims exist
    integer iLength = llGetListLength(lParams);
    if (iLength < 4)
    {
        return FALSE;
    }
    else if (iLength > 5)
    {
        return FALSE;
    }
    else if (!AnimExists(llList2String(lParams, 1)))
    {
        llOwnerSay(CARD1 + " line " + (string)g_iLine + ": animation '" + llList2String(lParams, 1) + "' is not present.  Skipping.");
        return FALSE;
    }
    else if (!AnimExists(llList2String(lParams, 2)))
    {
        llOwnerSay(CARD1 + " line " + (string)g_iLine + ": animation '" + llList2String(lParams, 2) + "' is not present.  Skipping.");
        return FALSE;
    }
    else
    {
        return TRUE;
    }
}

integer StartsWith(string sHayStack, string sNeedle) // http://wiki.secondlife.com/wiki/llSubStringIndex
{
    return llDeleteSubString(sHayStack, llStringLength(sNeedle), -1) == sNeedle;
}

string StringReplace(string sSrc, string sFrom, string sTo)
{//replaces all occurrences of 'sFrom' with 'sTo' in 'sSrc'.
    return llDumpList2String(llParseStringKeepNulls((sSrc = "") + sSrc, [sFrom], []), sTo);
}

PrettySay(string sText)
{
    string sName = llGetObjectName();
    list lWords = llParseString2List(sText, [" "], []);
    llSetObjectName(llList2String(lWords, 0));
    lWords = llDeleteSubList(lWords, 0, 0);
    llSay(0, "/me " + llDumpList2String(lWords, " "));
    llSetObjectName(sName);
}

string FirstName(string sName)
{
    return llList2String(llParseString2List(sName, [" "], []), 0);
}

//added to stop eventual still going animations
StopAnims()
{
    if (AnimExists(g_sSubAnim))
    {
        llMessageLinked(LINK_SET, ANIM_STOP, g_sSubAnim, NULL_KEY);
    }

    if (AnimExists(g_sDomAnim))
    {
        if (llKey2Name(g_kPartner) != "")
        {
            llStopAnimation(g_sDomAnim);
        } 
    }

    g_sSubAnim = "";
    g_sDomAnim = "";
}

// Calmly walk up to your partner and face them. Does not position the avatar precicely
MoveToPartner() {
    list partnerDetails = llGetObjectDetails(g_kPartner, [OBJECT_POS, OBJECT_ROT]);
    vector partnerPos = llList2Vector(partnerDetails, 0);
    rotation partnerRot = llList2Rot(partnerDetails, 1);
    vector partnerEuler = llRot2Euler(partnerRot);
    
    // turn to face the partner
    llMessageLinked(LINK_SET, RLV_CMD, "setrot:" + (string)(-PI_BY_TWO-partnerEuler.z) + "=force", NULL_KEY);
    
    g_iTargetID = llTarget(partnerPos, g_fWalkingDistance);
    llMoveToTarget(partnerPos, g_fWalkingTau);
}

AlignWithPartner() {
    float offset = 10.0;
    if (g_iCmdIndex != -1) offset = (float)llList2String(g_lAnimSettings, g_iCmdIndex * 4 + 2);
    list partnerDetails = llGetObjectDetails(g_kPartner, [OBJECT_POS, OBJECT_ROT]);
    vector partnerPos = llList2Vector(partnerDetails, 0);
    rotation partnerRot = llList2Rot(partnerDetails, 1);
    vector myPos = llList2Vector(llGetObjectDetails(llGetOwner(), [OBJECT_POS]), 0);

    vector target = partnerPos + (UNIT_VECTOR * partnerRot * offset); // target is <offset> meters in front of the partner
    target.z = myPos.z; // ignore height differences
    llMoveToTarget(target, g_fAlignTau);
    llSleep(g_fAlignDelay);
    llStopMoveToTarget();
}

PartnerRequest(string anim)
{
    llRequestPermissions(g_kPartner, PERMISSION_TRIGGER_ANIMATION);
    llInstantMessage(g_kPartner, FirstName(llKey2Name(llGetOwner())) + " would like give you a " + anim + ". Click [Yes] to accept." );
    g_lTimeouts += [llGetUnixTime() + g_iPermissionTimeout,"Permission",g_kPartner];
    checkTimer();    
}

checkTimer()
{
    integer i = 0;
    list lTemp=[];
    integer nextTime = 0;
    integer tmpTime = 0;
    integer iCurTime = llGetUnixTime();
    
    for (i=0; i < llGetListLength(g_lTimeouts); i=i+3)
    {
        if (iCurTime > llList2Integer(g_lTimeouts,i))
        {
            if(llList2String(g_lTimeouts,i+1) == "Anim")
            {
                StopAnims();
            }
            else if(llList2String(g_lTimeouts,i+1) == "Permission")
            {
                llListenRemove(g_iListener);
                llInstantMessage(g_kCmdGiver, g_sPartnerName + " did not accept your " + llList2String(g_lAnimCmds, g_iCmdIndex) + ".");
                g_kPartner = NULL_KEY;
            }
        }
        else
        {
            lTemp += llList2List(g_lTimeouts,i,i+2);
            tmpTime = llList2Integer(g_lTimeouts,i) - iCurTime;
            if  ((nextTime = 0) || tmpTime < nextTime)
            {
                nextTime = tmpTime;
            }
        }
    }
    llSetTimerEvent((float)nextTime);
}

init()
{
    g_kWearer = llGetOwner();
    g_iReady = FALSE;
    llMessageLinked(LINK_SET, MENUNAME_REMOVE, g_sParentMenu + "|" + g_sSubMenu, NULL_KEY);
    if (llGetInventoryType(CARD1) == INVENTORY_NOTECARD)
    {//card is present, start reading
        g_kCardID1 = llGetInventoryKey(CARD1);

        //re-initialize just in case we're switching from other state
        g_iLine = 0;
        g_lAnimCmds = [];
        g_lAnimSettings = [];
        g_sNoteCard2Read = CARD1;
        g_kDataID = llGetNotecardLine(g_sNoteCard2Read, g_iLine);
    }
}

/*---------------//
//  HANDLERS     //
//---------------*/

HandleHTTPDB(integer iSender, integer iNum, string sStr, key kID)
{
    if (iNum == HTTPDB_RESPONSE)
    {
        list lParams = llParseString2List(sStr, ["="], []);
        string sToken = llList2String(lParams, 0);
        string sValue = llList2String(lParams, 1);
        if(sToken == g_sDBToken)
        {
            g_iAnimTimeOut = (integer)sValue;
        }
    }
}

HandleDIALOG(integer iSender, integer iNum, string sStr, key kID)
{
    if (iNum == DIALOG_RESPONSE)
    {
        if (kID == g_kAnimmenu)
        {
            list lMenuParams = llParseString2List(sStr, ["|"], []);
            key kAv = (key)llList2String(lMenuParams, 0);
            string sMessage = llList2String(lMenuParams, 1);
            integer iPage = (integer)llList2String(lMenuParams, 2);
            if (sMessage == UPMENU)
            {
                llMessageLinked(LINK_SET, SUBMENU, g_sParentMenu, kAv);
            }
            else if (sMessage == STOP_COUPLES)
            {
                StopAnims();
                CoupleAnimMenu(kAv);
            }
            else if (sMessage == TIME_COUPLES)
            {
                TimerMenu(kAv);
            }
            else
            {
                integer iIndex = llListFindList(g_lAnimCmds, [sMessage]);
                if (iIndex != -1)
                {
                    g_kCmdGiver = kAv;
                    g_iCmdIndex = iIndex;
                    g_sSensorMode = "menu";
                    llSensor("", NULL_KEY, AGENT, g_fRange, PI);
                }
            }
        }
        else if (kID == g_kPart)
        {
            list lMenuParams = llParseString2List(sStr, ["|"], []);
            key kAv = (key)llList2String(lMenuParams, 0);
            string sMessage = llList2String(lMenuParams, 1);
            integer iPage = (integer)llList2String(lMenuParams, 2);
            if (sMessage == UPMENU)
            {
                CoupleAnimMenu(kAv);
            }
            else if ((integer)sMessage > 0 && ((string)((integer)sMessage) == sMessage))
            {
                g_iAnimTimeOut = ((integer)sMessage);
                llMessageLinked(LINK_SET, HTTPDB_SAVE, g_sDBToken + "=" + (string)g_iAnimTimeOut, NULL_KEY);
                Notify (kAv, "Couple Anmiations play now for " + (string)llRound(g_iAnimTimeOut) + " seconds.",TRUE);
                CoupleAnimMenu(kAv);
            }
            else if (sMessage == "endless")
            {
                g_iAnimTimeOut = 0;
                llMessageLinked(LINK_SET, HTTPDB_SAVE, g_sDBToken + "=" + (string)g_iAnimTimeOut, NULL_KEY);
                Notify (kAv, "Couple Anmiations play now for ever. Use the menu or type *stopcouples to stop them again.",TRUE);
            }
            else
            {
                integer iIndex = llListFindList(g_lPartners, [sMessage]);
                if (iIndex != -1)
                {
                    g_kPartner = llList2String(g_lPartners, iIndex - 1);
                    g_sPartnerName = sMessage;
                    //added to stop eventual still going animations
                    StopAnims();
                    string cmdName = llList2String(g_lAnimCmds, g_iCmdIndex);
                    PartnerRequest(cmdName);
                    llOwnerSay("Offering to " + cmdName + " " + g_sPartnerName + ".");
                }
            }
        }
    }
}

HandleMENU(integer iSender, integer iNum, string sStr, key kID)
{
    if (iNum == SUBMENU)
    {
        if (sStr == g_sSubMenu)
        {
            CoupleAnimMenu(kID);
        }
    }
    else if (iNum == MENUNAME_REQUEST && sStr == g_sParentMenu)
    {
        llMessageLinked(LINK_SET, MENUNAME_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, NULL_KEY);
    }
/*
    else if (iNum == MENUNAME_RESPONSE)
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
    else if (iNum == MENUNAME_REMOVE)
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

HandleCOMMAND(integer iSender, integer iNum, string sStr, key kID)
{
    if (iNum >= COMMAND_OWNER && iNum <= COMMAND_WEARER)
    {
        //the command was given by either owner, secowner, group member, or wearer
        list lParams = llParseString2List(sStr, [" "], []);
        g_kCmdGiver = kID;
        string sCommand = llToLower(llList2String(lParams, 0));
        string sValue = llToLower(llList2String(lParams, 1));
        integer tmpiIndex = llListFindList(g_lAnimCmds, [sCommand]);
        if (tmpiIndex != -1)
        {
            g_iCmdIndex = tmpiIndex;
            Debug(sCommand);
            //we got an anim command.
            //else set partner to commander
            if (llGetListLength(lParams) > 1)
            {
                //we've been given a name of someone to kiss.  scan for it
                g_sTmpName = llDumpList2String(llList2List(lParams, 1, -1), " ");//this makes it so we support even full names in the command
                g_sSensorMode = "chat";
                llSensor("", NULL_KEY, AGENT, g_fRange, PI);
            }
            else
            {
                //no name given.  if commander is not sub, then treat commander as partner
                if (kID == g_kWearer)
                {
                    llMessageLinked(LINK_SET, POPUP_HELP, "Error: you didn't give the name of the person you want to animate.  To " + sCommand + " Nandana Singh, for example, you could say /_CHANNEL__PREFIX" + sCommand + " nan", g_kWearer);
                }
                else
                {
                    g_kPartner = g_kCmdGiver;
                    g_sPartnerName = llKey2Name(g_kPartner);
                    //added to stop eventual still going animations
                    StopAnims();
                    PartnerRequest(sCommand);
                    llOwnerSay("Offering to " + sCommand + " " + g_sPartnerName + ".");
                }
            }
        }
        else if (sStr == "stopcouples")
        {
            StopAnims();
        }
        else if (sStr == "couples")
        {
            CoupleAnimMenu(kID);
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
        init();
    }

    link_message(integer iSender, integer iNum, string sStr, key kID)
    {
        if ((iNum >= HTTPDB_SAVE) && (iNum <= HTTPDB_EMPTY))
        {
            HandleHTTPDB(iSender,iNum,sStr,kID);
        }
        else if ((iNum >= MENUNAME_REQUEST) && (iNum <= MENUNAME_REMOVE))
        {
            HandleMENU(iSender,iNum,sStr,kID); 
        }
        if (g_iReady)
        {
            if ((iNum >= DIALOG_TIMEOUT) && (iNum <= DIALOG))
            {
                HandleDIALOG(iSender,iNum,sStr,kID);
            }        
            else if ((iNum >= COMMAND_OWNER) && (iNum <= COMMAND_RLV_RELAY))
            {
                HandleCOMMAND(iSender,iNum,sStr,kID);
            }
        }
    }
    
    listen(integer channel, string sName, key kID, string sMessage)
    {
        Debug("listen: " + sMessage + ", channel=" + (string)channel);
        llListenRemove(g_iListener);
        if (channel == g_iStopChan)
        {//this abuses the GROUP auth a bit but i think it's ok.
            Debug("message on stop channel");
            llMessageLinked(LINK_SET, COMMAND_GROUP, "stopcouples", kID);
        }
    }
    
    
    dataserver(key kID, string sData)
    {
        if (kID == g_kDataID)
        {
            if (sData == EOF)
            {
                if(g_sNoteCard2Read == CARD1)
                {
                    if(llGetInventoryType(CARD2) == INVENTORY_NOTECARD)
                    {
                        g_kCardID2 = llGetInventoryKey(CARD2);
                        g_sNoteCard2Read = CARD2;
                        g_iLine = 0;
                        g_kDataID = llGetNotecardLine(g_sNoteCard2Read, g_iLine);
                    }
                    else
                    {
                        //no Mycoupleanims notecard so...
                        g_iReady = TRUE;
                        llMessageLinked(LINK_SET, MENUNAME_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, NULL_KEY);
                    }
                }
                else
                {
                    Debug("done reading card");
                    g_iReady = TRUE;
                    llMessageLinked(LINK_SET, MENUNAME_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, NULL_KEY);
                }
            }
            else
            {
                list lParams = llParseString2List(sData, ["|"], []);
                //don't try to add empty or misformatted lines
                if (ValidLine(lParams))
                {
                    integer iIndex = llListFindList(g_lAnimCmds, llList2List(lParams, 0, 0));
                    if(iIndex == -1)
                    {
                        //add cmd, and text
                        g_lAnimCmds += llList2List(lParams, 0, 0);
                        //anim names, offset,
                        g_lAnimSettings += llList2List(lParams, 1, 3);
                        //text.  this has to be done by casting to string instead of list2list, else lines that omit text will throw off the stride
                        g_lAnimSettings += [llList2String(lParams, 4)];
                        Debug(llDumpList2String(g_lAnimCmds, ","));
                        Debug(llDumpList2String(g_lAnimSettings, ","));
                    }
                    else
                    {
                        iIndex = iIndex * 4;
                        //add cmd, and text
                        //g_lAnimCmds = llListReplaceList(g_lAnimCmds, llList2List(lParams, 0, 0), iIndex, iIndex);
                        //anim names, offset,
                        g_lAnimSettings = llListReplaceList(g_lAnimSettings, llList2List(lParams, 1, 3), iIndex, iIndex + 2);
                        //text.  this has to be done by casting to string instead of list2list, else lines that omit text will throw off the stride
                        g_lAnimSettings = llListReplaceList(g_lAnimSettings,[llList2String(lParams, 4)], iIndex + 3, iIndex + 3);
                        Debug(llDumpList2String(g_lAnimCmds, ","));
                        Debug(llDumpList2String(g_lAnimSettings, ","));
                    }
                }
                g_iLine++;
                g_kDataID = llGetNotecardLine(g_sNoteCard2Read, g_iLine);
            }
        }
    }

    on_rez(integer start)
    {

        //added to stop anims after relog when you logged off while in an endless couple anim
        if (g_sSubAnim != "" && g_sDomAnim != "")
        {
            // wait a second to make sure the poses script reseted properly
            llSleep(1.0);
            StopAnims();
        }
        llResetScript();
    }
    
    not_at_target()
    {
        //this might make us chase the partner.  we'll see.  that might not be bad
        llTargetRemove(g_iTargetID);
        MoveToPartner();
    }

    at_target(integer tiNum, vector targetpos, vector ourpos)
    {
        llTargetRemove(tiNum);
        llStopMoveToTarget();
        AlignWithPartner();
        //we've arrived.  let's play the anim and spout the text
        g_sSubAnim = llList2String(g_lAnimSettings, g_iCmdIndex * 4);
        g_sDomAnim = llList2String(g_lAnimSettings, g_iCmdIndex * 4 + 1);
        llMessageLinked(LINK_SET, ANIM_START, g_sSubAnim, NULL_KEY);
        llStartAnimation(g_sDomAnim);//note that we don't double check for permissions here, so if the coupleanim1 script sends its messages out of order, this might fail
        g_iListener = llListen(g_iStopChan, "", g_kPartner, g_sStopString);
        llInstantMessage(g_kPartner, "If you would like to stop the animation early, say /" + (string)g_iStopChan + g_sStopString + " to stop.");

        string text = llList2String(g_lAnimSettings, g_iCmdIndex * 4 + 3);
        if (text != "")
        {
            text = StringReplace(text, "_SELF_", FirstName(llKey2Name(g_kWearer)));
            text = StringReplace(text, "_PARTNER_", FirstName(g_sPartnerName));
            PrettySay(text);
        }
        g_lTimeouts += [llGetUnixTime() + g_iAnimTimeOut,"Anim",g_kPartner];
        checkTimer();
    }

    timer()
    {
        checkTimer();
    }

    sensor(integer iNum)
    {
        Debug(g_sSensorMode);
        if (g_sSensorMode == "menu")
        {
            g_lPartners = [];
            list kAvs;//just used for menu building
            integer n;
            for (n = 0; n < iNum; n++)
            {
                g_lPartners += [llDetectedKey(n), llDetectedName(n)];
                kAvs += [llDetectedName(n)];
            }
            PartnerMenu(g_kCmdGiver, kAvs);
        }
        else if (g_sSensorMode == "chat")
        {
            //loop through detected avs, seeing if one matches g_sTmpName
            integer n;
            for (n = 0; n < iNum; n++)
            {
                string sName = llDetectedName(n);
                if (StartsWith(llToLower(sName), llToLower(g_sTmpName)) || llToLower(sName) == llToLower(g_sTmpName))
                {
                    g_kPartner = llDetectedKey(n);
                    g_sPartnerName = sName;
                    string sCommand = llList2String(g_lAnimCmds, g_iCmdIndex);
                    //added to stop eventual still going animations
                    StopAnims();
                    PartnerRequest(sCommand);
                    llOwnerSay("Offering to " + sCommand + " " + g_sPartnerName + ".");
                    return;
                }
            }
            //if we got to this point, then no one matched
            llInstantMessage(g_kCmdGiver, "Could not find '" + g_sTmpName + "' to " + llList2String(g_lAnimCmds, g_iCmdIndex) + ".");
        }
    }

    no_sensor()
    {
        if (g_sSensorMode == "chat")
        {
            llInstantMessage(g_kCmdGiver, "Could not find '" + g_sTmpName + "' to " + llList2String(g_lAnimCmds, g_iCmdIndex) + ".");
        }
        else if (g_sSensorMode == "menu")
        {
            llInstantMessage(g_kCmdGiver, "Could not find anyone nearby to " + llList2String(g_lAnimCmds, g_iCmdIndex) + ".");
            CoupleAnimMenu(g_kCmdGiver);
        }
    }

    changed(integer iChange)
    {
        if (iChange & CHANGED_INVENTORY)
        {
            if (llGetInventoryKey(CARD1) != g_kCardID1)
            {
                //because notecards get new uuids on each save, we can detect if the notecard has changed by seeing if the current uuid is the same as the one we started with
                //just switch states instead of restarting, so we can preserve any settings we may have gotten from db
                init();
            }
            if (llGetInventoryKey(CARD2) != g_kCardID1)
            {
                init();
            }
        }
    }
        
    run_time_permissions(integer perm)
    {
        if (perm & PERMISSION_TRIGGER_ANIMATION)
        {
            key kID = llGetPermissionsKey();
            if (kID == g_kPartner)
            {
                integer index = llListFindList(g_lTimeouts,["Permission",g_kPartner]);
                if (index != -1)
                {
                    g_lTimeouts = llDeleteSubList(g_lTimeouts,index-1,index+1);
                    MoveToPartner();
                }
            }
            else
            {
                llInstantMessage(kID, "Sorry, but the request timed out.");
            }
        }
    }           
}

