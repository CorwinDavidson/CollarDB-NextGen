/*--------------------------------------------------------------------------------**
**  File: CDB - leash                                                             **
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

// ------ TOKEN DEFINITIONS ------
// ---- Immutable ----
// - Should be constant across collars, so not prefixed
// --- db tokens ---
string TOK_LENGTH   = "leashlength";
string TOK_ROT = "leashrot";
string TOK_DEST     = "leashedto"; // format: uuid,rank
// --- channel tokens ---

integer LOCKMEISTER         = -8888;

// --- menu tokens ---
string MORE         = ">";
string g_sParentMenu   = "Main";
string g_sSubMenu      = "Leash";
string LEASH        = "Grab";
string LEASH_TO     = "LeashTo";
string FOLLOW       = "Follow Me";
string FOLLOW_MENU  = "FollowTarget";
string UNLEASH      = "Unleash";
string UNFOLLOW     = "Unfollow";
string STAY         = "Stay";
string UNSTAY       = "UnStay";
string ROT         = "Rotate";
string UNROT       = "Don't Rotate";
string L_LENGTH     = "Length";
string GIVE_HOLDER  = "Give Holder";
string GIVE_POST    = "Give Post";
string REZ_POST     = "Rez Post";
string L_POST       = "Post";
string L_YANK       = "Yank";
string L_BECKON       = "Beckon";

// --- tokens for g_iSensorMode ---
// - to remember what the sensor is tracking
// sensors for chat
integer SENSORMODE_FIND_TARGET_FOR_LEASH_CHAT   = 1;
integer SENSORMODE_FIND_TARGET_FOR_FOLLOW_CHAT  = 2;
integer SENSORMODE_FIND_TARGET_FOR_POST_CHAT    = 3;
// sensors for menus
integer SENSORMODE_FIND_TARGET_FOR_LEASH_MENU   = 100;
integer SENSORMODE_FIND_TARGET_FOR_FOLLOW_MENU  = 101;
integer SENSORMODE_FIND_TARGET_FOR_POST_MENU    = 102;

// ---------------------------------------------
// ------ VARIABLE DEFINITIONS ------
// ----- menu -----

string g_sCurrentMenu = "";

string g_sWearer;
string g_sMenuUser;

list g_oButtons = [LEASH, FOLLOW, L_YANK];

list g_lPostKeys;

// ----- collar -----

integer g_iJustMoved;
// ----- leash -----
float g_fLength = 3.0;
float g_fScanRange = 10.0;
integer g_iStay = FALSE;
integer g_iRot = TRUE;
integer g_iTargetHandle;
integer g_iLastRank;
integer g_iStayRank;
vector g_vPos = ZERO_VECTOR;
string g_sSensorMode;
string g_sTmpName;
key g_kCmdGiver;
//key g_kLeashHolder;
key g_kLeashedTo = NULL_KEY;
integer g_bLeashedToAvi;
integer g_bFollowMode = FALSE;

integer g_iReturnMenu = TRUE;
integer g_iSensorMode = 0;
key g_kMenuUser;

list g_lLeashers;
list g_lLengths = ["1", "2", "3", "4", "5", "8","10" , "15", "20", "25", "30"];

integer g_iUnixTime;

$import lib.MessageMap.lslm ();
$import lib.CommonVariables.lslm ();
$import lib.CommonFunctions.lslm ();

/*---------------//
//  FUNCTIONS    //
//---------------*/

// RLV-Force avatar to face the leasher by Tapple Gao
turnToTarget(vector target)
{
    if (g_iRot)
    {
        // do not need this as we are only doint at target
        //float MAX_TURN_ANGLE = 70 * DEG_TO_RAD;
        vector pointTo = target - llGetPos();
        //vector myEuler = llRot2Euler(llGetRot());
        //float  myAngle = PI_BY_TWO - myEuler.z;
        float  turnAngle = llAtan2(pointTo.x, pointTo.y);// - myAngle;
        //while (turnAngle < -PI) turnAngle += TWO_PI;
        //while (turnAngle >  PI) turnAngle -= TWO_PI;
        //if (turnAngle < -MAX_TURN_ANGLE) turnAngle = -MAX_TURN_ANGLE;
        //if (turnAngle >  MAX_TURN_ANGLE) turnAngle =  MAX_TURN_ANGLE;
        llMessageLinked(LINK_SET, RLV_CMD, "setrot:" + (string)(turnAngle) + "=force", NULL_KEY);
    }
}

integer CheckCommandAuth(key kCmdGiver, integer iAuth)
{
    // Check for invalid auth
    if (iAuth < COMMAND_OWNER && iAuth > COMMAND_WEARER)
        return FALSE;
    
    // If leashed, only move leash if Comm Giver outranks current leasher
    if (g_kLeashedTo != NULL_KEY && iAuth > g_iLastRank)
    {
        string sFirstName = GetFirstName(g_sWearer);
        Notify(kCmdGiver, "Sorry, someone who outranks you on " + g_sWearer +"'s collar leashed " + sFirstName + " already.", FALSE);

        return FALSE;
    }

    return TRUE;
}

LeashMenu(key kIn)
{
    g_sCurrentMenu = "leash";
    g_iReturnMenu = FALSE;

    list lButtons = [];
    if (kIn != g_kWearer)
    {    
        lButtons += g_oButtons; // Only if not the wearer.
        if (g_kLeashedTo != NULL_KEY)
            lButtons += [L_YANK];
        else
            lButtons += [L_BECKON];
    }
        
    lButtons += g_lButtons;
    
    if (g_kLeashedTo != NULL_KEY)
    {
        if (g_bFollowMode)
            lButtons += [UNFOLLOW];
        else
            lButtons += [UNLEASH];
    }
    
    if (g_iStay)
        lButtons += [UNSTAY];
    else
        lButtons += [STAY];

    if (kIn == g_kWearer) // Only for wearer.
    {
        if (g_iRot)
            lButtons += [UNROT];
        else
            lButtons += [ROT];
    }    

    string sPrompt = "Leash Options";
    g_kDialogID = Dialog(kIn, sPrompt, lButtons, [UPMENU], 0);
}

LengthMenu(key kIn)
{
    g_sCurrentMenu = "length";
    string sPrompt = "Set a leash length in meter:\nCurrent length is: " + (string)g_fLength + "m";
    g_kDialogID = Dialog(kIn, sPrompt, g_lLengths, [UPMENU], 0);
}


SetLength(float fIn)
{
    g_fLength = fIn;
    // llTarget needs to be changed to the new length if leashed
    if(g_kLeashedTo != NULL_KEY)
    {
        llTargetRemove(g_iTargetHandle);
        g_iTargetHandle = llTarget(g_vPos, g_fLength);
    }
}

// Wrapper to send notices to wearer, leasher, and target
// Only sends notices if Leasher is an AV, as objects normally handle their own messages for such things
SayLeashed(key kTarget,key kCmdGiver, integer iAuth)
{
    if (!KeyIsAv(g_kCmdGiver)) return; // failsafe
    string sTarget = llKey2Name(kTarget);
    string sWearMess;
    if (kCmdGiver == g_kWearer) // Wearer is Leasher
    {
        //sCmdMess = ""; // Only one message will need to be sent
        sWearMess = "You take your leash";
        if (kTarget == g_kWearer) // self bondage - shouldn't ever happen, but just in case
        {
            //sWearMess += ""; // We could put in some sort of self-deprecating humor here ;)
        }
        else if (KeyIsAv(kTarget)) // leashing self to someone else
        {
            sWearMess += ", and hand it to " + sTarget;
        }
        else // leashing self to an object
        {
            sWearMess += ", and tie it to " + sTarget;
        }
    }
    else // Leasher is not Wearer
    {
        string sPsv = "'s"; // Possessive, will vary if name ends in "s"
        if (endswith(g_sWearer, "s")) sPsv = "'";
        string sCmdMess= "You grab " + g_sWearer + sPsv + " leash";
        sWearMess = llKey2Name(kCmdGiver) + " grabs your leash";
        if (kCmdGiver != kTarget) // Leasher is not LeashTo
        {
            if (kTarget == g_kWearer) // LeashTo is Wearer
            {
                sCmdMess += ", and hand it to " + GetFirstName(g_sWearer);
                sWearMess += ", and hands it to you";
            }
            else if (KeyIsAv(kTarget)) // LeashTo someone else
            {
                sCmdMess += ", and hand it to " + sTarget;
                sWearMess += ", and hands it to " + sTarget;
                Notify(kTarget, llKey2Name(kCmdGiver) + " hands you " + g_sWearer + sPsv + " leash", FALSE);
            }
            else // LeashTo object
            {
                sCmdMess += ", and tie it to " + sTarget;
                sWearMess += ", and ties it to " + sTarget;
            }
        }
        Notify(kCmdGiver, sCmdMess, FALSE);
    }
    Notify(g_kWearer, sWearMess, FALSE);
}

SayUnleash(key kTarget, key kCmdGiver, integer iAuth)
{
    string sTarget = llKey2Name(g_kLeashedTo);
    string sCmdGiver = llKey2Name(kCmdGiver);
    string sWearMess;
    string sCmdMess;
    string sTargetMess;
    Debug((string)g_kLeashedTo);
    if (!KeyIsAv(kTarget))
        return;
        
    if (g_kWearer == kCmdGiver) // Wearer is Leasher
    {
        sWearMess = "You unleash yourself from " + sTarget + "."; // sTarget might be an object
        sTargetMess = GetFirstName(g_sWearer) + " unleashes from you.";
        if (KeyIsAv(g_kLeashedTo))
            Notify(g_kLeashedTo, sTargetMess, FALSE);
    }
    else // Unleasher is not Wearer
    {
        if (kCmdGiver == g_kLeashedTo)
        {
            sCmdMess= "You unleash  " + g_sWearer + ".";
            sWearMess = sCmdGiver + " unleashes you.";
        }
        else
        {
            sCmdMess= "You unleash  " + GetFirstName(g_sWearer) + " from " + sTarget + ".";
            sWearMess = sCmdGiver + " unleashes you from " + sTarget + ".";
            sTargetMess = sCmdGiver + " unleashes " + GetFirstName(g_sWearer) + " from you.";
            if (KeyIsAv(g_kLeashedTo))
                Notify(g_kLeashedTo, sTargetMess, FALSE);
        }
        Notify(kTarget, sCmdMess, FALSE);
    }
    Notify(g_kWearer, sWearMess, FALSE);
}

SayFollow(key kTarget, key kCmdGiver, integer iAuth)
{
    // TODO: why this??  It seems to have something to do with getting commands from objects.
    if (kTarget == kCmdGiver && llGetOwnerKey(kCmdGiver) == g_kWearer) 
        return;

    // Send notices to wearer, leasher, and target
    // Only send notices if Leasher is an AV, as objects normally handle their own messages for such things
    if (KeyIsAv(kCmdGiver)) 
    {
        string sTarget = llKey2Name(kTarget);
        string sWearMess;
        if (kCmdGiver == g_kWearer) // Wearer is Leasher
        {
            //sCmdMess = ""; // Only one message will need to be sent
            sWearMess = "You begin following " + sTarget + ".";
        }
        else // Leasher is not Wearer
        {
            string sCmdMess= "You command " + g_sWearer + " to follow " + sTarget + ".";
            sWearMess = llKey2Name(kCmdGiver) + " commands you to follow " + sTarget + ".";
            if (KeyIsAv(kTarget)) // LeashTo someone else
                Notify(kTarget, llKey2Name(kCmdGiver) + " commands " + g_sWearer + " to follow you.", FALSE);
            
            Notify(kCmdGiver, sCmdMess, FALSE);
        }
        Notify(g_kWearer, sWearMess, FALSE);
    }
}

SayUnfollow(key kTarget, key kCmdGiver, integer iAuth)
{
    string sTarget = llKey2Name(g_kLeashedTo);
    string sCmdGiver = llKey2Name(kTarget);
    string sWearMess;
    string sCmdMess;
    string sTargetMess;
    
    if (!KeyIsAv(kTarget))
        return;

    if (kTarget == g_kWearer) // Wearer is Leasher
    {
        sWearMess = "You stop following " + sTarget + ".";
        sTargetMess = GetFirstName(g_sWearer) + " stops following you.";
        if (KeyIsAv(g_kLeashedTo))
            Notify(g_kLeashedTo, sTargetMess, FALSE);
    }
    else // Unleasher is not Wearer
    {
        if (kCmdGiver == g_kLeashedTo)
        {
            sCmdMess= "You release " + GetFirstName(g_sWearer) + " from following you.";
            sWearMess = sCmdGiver + " releases you from following.";
        }
        else
        {
            sCmdMess= "You release " + GetFirstName(g_sWearer) + " from following " + sTarget + ".";
            sWearMess = sCmdGiver + " releases you from following " + sTarget + ".";
            sTargetMess = g_sWearer + " stops following you.";
            if (KeyIsAv(g_kLeashedTo))
                Notify(g_kLeashedTo, sTargetMess, FALSE);
        }
        Notify(kTarget, sCmdMess, FALSE);
    }
    Notify(g_kWearer, sWearMess, FALSE);
}

// Wrapper for DoLeash, so that on restoring leash from localsettings we can call DoLeash and not redundantly save the settings again.
LeashTo(key kTarget, key kCmdGiver, integer iRank, list lPoints)
{
    // can't leash wearer to self.
    if (kTarget == g_kWearer)
        return;
    
    if (g_bFollowMode)
        SayFollow(kTarget, kCmdGiver, iRank);
    else
        SayLeashed(kTarget, kCmdGiver, iRank);
    
    if (!g_bLeashedToAvi)
    {
        if (KeyIsAv(kTarget))
        {
            g_bLeashedToAvi = TRUE;
        }
    }
    llMessageLinked(LINK_SET, SETTING_SAVE, TOK_DEST + "=" + (string)kTarget + "," + (string)iRank + "," + (string)g_bLeashedToAvi + "," + (string)g_bFollowMode, NULL_KEY);
    DoLeash(kTarget, iRank, lPoints);
    
    // Notify Target how to unleash, only if:
    // Avatar
    // Didn't send the command
    // Don't own the object that sent the command
    if (KeyIsAv(kTarget) && kCmdGiver != kTarget && llGetOwnerKey(kCmdGiver) != kTarget)
    {
        if (g_bFollowMode)
            FollowHelp(g_kLeashedTo);
        else
            LeashToHelp(g_kLeashedTo);
    }    
}

DoLeash(key kTarget, integer iRank, list lPoints)
{
    g_iLastRank = iRank;
    g_kLeashedTo = kTarget;
    
    if (g_bFollowMode)
    {
        llMessageLinked(LINK_THIS, COMMAND_PARTICLE, "unleash", g_kLeashedTo);
    }
    else
    {
        integer iPointCount = llGetListLength(lPoints);
        string sCheck = "";  
        if (iPointCount)
        {//if more than one leashpoint, listen for all strings, else listen just for that point
            if (iPointCount == 1) sCheck = (string)llGetOwnerKey(kTarget) + llList2String(lPoints, 0) + " ok";
        }
        //Send link message to the particle script 
        llMessageLinked(LINK_THIS, COMMAND_PARTICLE, "leash" + sCheck + "|" + (string)g_bLeashedToAvi, g_kLeashedTo);
    }

    // change to llTarget events by Lulu Pink 
    g_vPos = llList2Vector(llGetObjectDetails(g_kLeashedTo, [OBJECT_POS]), 0);
    //to prevent multiple target events and llMoveToTargets
    llTargetRemove(g_iTargetHandle);
    llStopMoveToTarget();
    g_iTargetHandle = llTarget(g_vPos, g_fLength);
    if (g_vPos != ZERO_VECTOR)
    {
        //turnToTarget(g_vPos);// only at target
        llMoveToTarget(g_vPos, 0.7);
    }
    g_iUnixTime = llGetUnixTime();
}

// sets up a sensor callback which locates potential targets to display menu for leash / follow / post
DisplayTargetMenu(key kCmdGiver, integer iAuth, integer iSensorMode, string sChattedTarget)
{
    if (iSensorMode == SENSORMODE_FIND_TARGET_FOR_POST_CHAT)
    {
        if (llStringLength(sChattedTarget) == 0)
            return;
    }
    g_iSensorMode = iSensorMode;
    g_kMenuUser = kCmdGiver;
    g_iLastRank = iAuth;
    if ((iSensorMode == SENSORMODE_FIND_TARGET_FOR_POST_MENU) || (iSensorMode == SENSORMODE_FIND_TARGET_FOR_POST_CHAT))
        llSensor("", NULL_KEY, PASSIVE | ACTIVE, g_fScanRange, PI);
    else
        llSensor("", "", AGENT, g_fScanRange, PI);
}

StayPut(key kIn, integer iRank)
{
    g_iStayRank = iRank;
    g_iStay = TRUE;
    llRequestPermissions(g_kWearer, PERMISSION_TAKE_CONTROLS);
    llOwnerSay(llKey2Name(kIn) + " commanded you to stay in place, you cannot move until the command is revoked again.");
    Notify(kIn, "You commanded " + g_sWearer + " to stay in place. Either leash the slave with the grab command or use \"unstay\" to enable movement again.", FALSE);
}

CleanUp()
{
    llTargetRemove(g_iTargetHandle);
    llStopMoveToTarget();
}

Unleash(key kCmdGiver)
{
    Debug((string)g_kLeashedTo + " " + (string)kCmdGiver);
    Debug(llKey2Name(g_kLeashedTo) + " " + llKey2Name(kCmdGiver));    
    if (g_bFollowMode)
    {
        g_bFollowMode = FALSE;
        SayUnfollow(g_kLeashedTo,kCmdGiver,0);
    }
    else
        SayUnleash(g_kLeashedTo,kCmdGiver,0);
    
    CleanUp();
    llMessageLinked(LINK_THIS, COMMAND_PARTICLE, "unleash", g_kLeashedTo);
    g_kLeashedTo = NULL_KEY;
    g_iLastRank = COMMAND_EVERYONE;
    llMessageLinked(LINK_SET, SETTING_DELETE, TOK_DEST, "");
}

// Returns sName's first name
string GetFirstName(string sName)
{
    return llGetSubString(sName, 0, llSubStringIndex(sName, " ") - 1);
}

LeashToHelp(key kIn)
{
    llMessageLinked(LINK_SET, POPUP_HELP, g_sWearer + " has been leashed to you.  Say \"_PREFIX_unleash\" to unleash them.  Say \"_PREFIX_giveholder\" to get a leash holder.", kIn);
}

FollowHelp(key kIn)
{
    llMessageLinked(LINK_SET, POPUP_HELP, g_sWearer + " has been commanded to follow you.  Say \"_PREFIX_unfollow\" to relase them.", kIn);
}

YankTo(key kIn)
{
    llMoveToTarget(llList2Vector(llGetObjectDetails(kIn, [OBJECT_POS]), 0), 0.5);
    llSleep(2.0);
    llStopMoveToTarget();    
}

/*---------------//
//  HANDLERS     //
//---------------*/
// pragma inline
HandleHTTPDB(integer iSender, integer iNum, string sStr, key kID)
{

}
// pragma inline
HandleLOCALSETTING(integer iSender, integer iNum, string sStr, key kID)
{
    if (iNum == SETTING_RESPONSE)
    {
        integer iInd = llSubStringIndex(sStr, "=");
        string sTOK = llGetSubString(sStr, 0, iInd -1);
        string sVAL = llGetSubString(sStr, iInd + 1, -1);
        if (sTOK == TOK_DEST)
        {
            //we got the last leasher's id and rank from the local settings
            list lParam = llParseString2List(llGetSubString(sStr, iInd + 1, -1), [","], []);
            key kTarget = (key)llList2String(lParam, 0);
            g_bLeashedToAvi = (integer)llList2String(lParam, 2);
            g_bFollowMode = (integer)llList2String(lParam, 3);
            list lPoints;
            if (g_bLeashedToAvi)
            {
                lPoints = ["collar", "handle"];
            }
            DoLeash(kTarget, (integer)llList2String(lParam, 1), lPoints);                
        }
        else if (sTOK == TOK_LENGTH)
        {
            SetLength((float)sVAL);
        }
        else if (sTOK == TOK_ROT)
        {
            g_iRot = (integer)sVAL;
        }
    }
}
// pragma inline
HandleDIALOG(integer iSender, integer iNum, string sStr, key kID)
{
    if (iNum == DIALOG_RESPONSE)
    {
        if (kID == g_kDialogID)
        {
            list lMenuParams = llParseString2List(sStr, ["|"], []);
            key kAV = (key)llList2String(lMenuParams, 0);          
            string sButton = llList2String(lMenuParams, 1);
            g_sMenuUser = kAV;
            
            if(sButton == UPMENU)
            {
                if(g_sCurrentMenu == "length" || g_sCurrentMenu == "leashto" || g_sCurrentMenu == "post")
                {
                    LeashMenu(kAV);
                }
                else
                {
                    llMessageLinked(LINK_SET, MENU_SUBMENU, g_sParentMenu, kAV);
                    return;
                }
            }                
            else if(sButton == L_LENGTH)
            {
                LengthMenu(kAV);
                return;
            }
            else if(sButton == GIVE_HOLDER)
                llMessageLinked(LINK_SET, COMMAND_NOAUTH, "giveholder", kAV);
            else if(sButton == GIVE_POST)
                llMessageLinked(LINK_SET, COMMAND_NOAUTH, "givepost", kAV);
            else if(sButton == REZ_POST)
                llMessageLinked(LINK_SET, COMMAND_NOAUTH, "rezpost", kAV);
            else if((sButton == LEASH_TO) || (sButton == FOLLOW_MENU) || (sButton == L_POST))
            {
                llMessageLinked(LINK_SET, COMMAND_NOAUTH, sButton, kAV);
            }                            
            else if(llListFindList(g_lLengths,[sButton]) != -1)
            {
                llMessageLinked(LINK_SET, COMMAND_NOAUTH, "length " + sButton, kAV);
                LengthMenu(kAV);
                return; // no re-main leash menu                    
            }
            else
            {
                if ((g_iSensorMode >= SENSORMODE_FIND_TARGET_FOR_LEASH_MENU) && (g_iSensorMode <= SENSORMODE_FIND_TARGET_FOR_POST_MENU))
                {                        
                    if ((key)sButton)
                    {
                        g_kLeashedTo = (key)sButton;
                        if (g_iSensorMode == SENSORMODE_FIND_TARGET_FOR_FOLLOW_MENU)
                        {
                            g_bFollowMode = TRUE;
                            LeashTo(g_kLeashedTo, g_kCmdGiver, g_iLastRank, ["collar", "handle"]);
                            //SayFollow(g_kLeashedTo, g_kCmdGiver, g_iLastRank);
                        }
                        else if(g_iSensorMode == SENSORMODE_FIND_TARGET_FOR_LEASH_MENU)
                        {
                            if (CheckCommandAuth(g_kCmdGiver, g_iLastRank))
                                LeashTo(g_kLeashedTo, g_kCmdGiver, g_iLastRank, ["collar", "handle"]);
                        }
                        else if(g_iSensorMode == SENSORMODE_FIND_TARGET_FOR_POST_MENU)
                        {
                                llMessageLinked(LINK_SET, COMMAND_NOAUTH, "post " + sButton + " collar post", kAV);
                        }
                        if (!g_iReturnMenu) return;
                    }
                } 
                llMessageLinked(LINK_SET, COMMAND_NOAUTH, llToLower(sButton), kAV);
                list lTemp = [LEASH, L_YANK, UNLEASH];
                if (!~llListFindList(lTemp, [sButton]))
                {
                    return;
                }                                    
            }                
            LeashMenu(kAV);
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
            LeashMenu(kID);
        }
        else if (sStr == UPMENU)
        {
            llMessageLinked(LINK_SET, MENU_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, NULL_KEY);
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
    list lParam = [];
    list lPoints = [];
    string sMesL = llToLower(sStr);
    if (iNum >= COMMAND_OWNER && iNum <= COMMAND_WEARER)
    {
        g_kCmdGiver = kID;
        lParam = llParseString2List(sStr, [" "], []);
        string sComm = llToLower(llList2String(lParam, 0));
        if (sMesL == "grab" || sMesL == "leash" || (sMesL == "toggleleash" && NULL_KEY == g_kLeashedTo))
        {
            if (CheckCommandAuth(kID, iNum)) LeashTo(kID, kID, iNum, ["handle"]);
        }
        else if(sComm == "follow")
        {
            if (CheckCommandAuth(kID, iNum))
            {
                string sChattedTarget = llList2String(lParam, 1);
                if (sMesL == sComm) // no parameters were passed
                {
//                        SayFollow(kID, kID, iNum);
                    g_bFollowMode = TRUE;
                    LeashTo(kID, kID, iNum, ["handle"]);
                }       
                else if ((key)sChattedTarget)
                {
//                        SayFollow((key)sChattedTarget, kID, iNum);
                    g_bFollowMode = TRUE;
                    LeashTo(kID, kID, iNum, ["handle"]);
                } 
                else
                {
                    g_iReturnMenu = FALSE;
                    DisplayTargetMenu(kID, iNum, SENSORMODE_FIND_TARGET_FOR_FOLLOW_CHAT, sChattedTarget);
                }
            }
            if (!g_iReturnMenu) return;
        }
        else if (sMesL == "unleash" || sMesL == "unfollow" || (sMesL == "toggleleash" && NULL_KEY != g_kLeashedTo))
        {
            if (CheckCommandAuth(kID, iNum)) 
                    Unleash(kID);
        }
        else if (sMesL == "giveholder")
        {
            llGiveInventory(kID, "DB Leash Holder");
        }
        else if (sMesL == "givepost")
        {
            llGiveInventory(kID, "DB_Leash_Post");
        }
        else if (sMesL == "rezpost")
        {
            llRezObject("DB_Leash_Post", llGetPos() + (<1.0, 0, -0.3> * llGetRot()), ZERO_VECTOR, llEuler2Rot(<0, 90, 0> * DEG_TO_RAD), 0);
        }
        else if (sMesL == "yank" && kID == g_kLeashedTo)
        {
            //Person holding the leash can yank.
            YankTo(kID);
        }
        else if (sMesL == "beckon" && iNum == COMMAND_OWNER)
        {
            //Owner can beckon
            YankTo(kID);
        }
        else if (sMesL == "stay")
        {
            if (iNum <= COMMAND_GROUP)
            {
                StayPut(kID, iNum);
            }
        }
        else if ((sMesL == "unstay" || sMesL == "move") && g_iStay)
        {
            if (iNum <= g_iStayRank)
            {
                g_iStay = FALSE;
                llReleaseControls();
                llOwnerSay("You are free to move again.");
                Notify(kID,"You allowed " + g_sWearer + " to move freely again.", FALSE);
            }
        }
        else if(sMesL == "don't rotate" && g_iRot)
        {
            if (g_kWearer == kID)
            {
                g_iRot = FALSE;
                llMessageLinked(LINK_SET, SETTING_SAVE, TOK_ROT + "=0", "");
            }
            else
            {
                Notify(kID,"Only the wearer can change the rotate setting", FALSE);
            }
        }
        else if(sMesL == "rotate" && !g_iRot)
        {
            if (g_kWearer == kID)
            {
                g_iRot = TRUE;
                llMessageLinked(LINK_SET, SETTING_DELETE, TOK_ROT, "");
            }
            else
            {
                Notify(kID,"Only the wearer can change the rotate setting", FALSE);
            }
        }
        else
        {
            jump othermenu;
        }
        if (g_iReturnMenu)
        {
            LeashMenu(kID);
        }
        return;
        @othermenu;
        if(sMesL == "leashmenu" || sStr == "menu " + g_sSubMenu)
        {

            if (CheckCommandAuth(kID, iNum)) 
                LeashMenu(kID);
            else if (sMesL == "menu " + g_sSubMenu) 
            {
                llMessageLinked(LINK_SET, iNum, "menu " + g_sParentMenu, kID); 
                return;
            }
        }            
        else if(sComm == "leashto")
        {
            if (!CheckCommandAuth(kID, iNum)) 
                return;
            
            string sChattedTarget = llList2String(lParam, 1);
            
            if (sMesL == sComm) // no parameters were passed
            {
                DisplayTargetMenu(kID, iNum, SENSORMODE_FIND_TARGET_FOR_LEASH_MENU,"");
            }       
            else if((key)sChattedTarget)
            {
                if (llGetListLength(lParam) > 2) 
                    lPoints = llList2List(lParam, 2, -1);
                LeashTo((key)sChattedTarget, kID, iNum, lPoints);
            }
            else
            {
                DisplayTargetMenu(kID, iNum, SENSORMODE_FIND_TARGET_FOR_LEASH_CHAT, sChattedTarget);
            }                
            if (!g_iReturnMenu) return;
        }
        else if(sComm == "followtarget")
        {
            if (!CheckCommandAuth(kID, iNum)) 
                return;
                
            DisplayTargetMenu(kID, iNum, SENSORMODE_FIND_TARGET_FOR_FOLLOW_MENU,"");
            if (!g_iReturnMenu) return;
        }
        else if (sComm == "length")
        {
            float fNewLength = (float)llList2String(lParam, 1);
            if(fNewLength > 0.0)
            {
                if (kID == g_kLeashedTo || CheckCommandAuth(kID, iNum)) 
                {
                    SetLength(fNewLength);
                    //tell wearer  
                    Notify(kID, "Leash length set to " + (string)fNewLength, TRUE);        
                    llMessageLinked(LINK_SET, SETTING_SAVE, TOK_LENGTH + "=" + (string)fNewLength, "");
                }
            }
            else Notify(kID, "The current leash length is " + (string)g_fLength + "m.", TRUE);
        }
        else if (sComm == "post")
        {
            string sChattedTarget = llList2String(lParam, 1);
            if (!CheckCommandAuth(kID, iNum)) return;

            else if (sMesL == sComm) // no parameters were passed
            {
                DisplayTargetMenu(kID, iNum, SENSORMODE_FIND_TARGET_FOR_POST_MENU, "");
            }       
            else if((key)sChattedTarget)
            {
                lPoints;
                if (llGetListLength(lParam) > 2) lPoints = llList2List(lParam, 2, -1);
                //debug("leash target is key");//could be a post, or could be we specified an av key
                LeashTo((key)sChattedTarget, kID, iNum, lPoints);
            }
            else
            {
                DisplayTargetMenu(kID, iNum, SENSORMODE_FIND_TARGET_FOR_POST_CHAT, sChattedTarget);
            }
            if (!g_iReturnMenu) return;
        }
        return;
    }
    else if (iNum == COMMAND_EVERYONE)
    {
        if (kID == g_kLeashedTo)
        {
            if (sMesL == "unleash" || sMesL == "unfollow" || (sMesL == "toggleleash" && NULL_KEY != g_kLeashedTo))
            {
                Unleash(kID);
            }
            else if (sMesL == "giveholder")
            {
                llGiveInventory(kID, "DB Leash Holder");
            }
            else if (sMesL == "yank")
            {
                YankTo(kID);
            }
        }
        return;
    } 
    else if (iNum == COMMAND_SAFEWORD)
    {
        if(g_iStay)
        {
            g_iStay = FALSE;
            llReleaseControls();
        }
        Unleash(kID);
        return;
    }
        
}


/*---------------//
//  MAIN CODE    //
//---------------*/
default
{
    state_entry()
    {
    	g_lButtons = [L_LENGTH, LEASH_TO, FOLLOW_MENU, GIVE_HOLDER, L_POST, REZ_POST, GIVE_POST];
        //debug("statentry:"+(string)llGetFreeMemory( ));
        g_kWearer = llGetOwner();
        g_sWearer = llKey2Name(g_kWearer);
        llMinEventDelay(0.3);
        //g_sMyID =  llList2String(llParseString2List(llGetObjectDesc(), ["~"], []), 2);
        Unleash(g_kWearer);
        //llOwnerSay("stateentryend:"+(string)llGetFreeMemory());
    }
    
    on_rez(integer start_param)
    {
        llResetScript();
    }
    
    link_message(integer iSender, integer iNum, string sStr, key kID)
    {
        if ((iNum >= SETTING_SAVE) && (iNum <= SETTING_EMPTY))
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
        else if ((iNum >= COMMAND_OWNER) && (iNum <= COMMAND_SAFEWORD))
        {
            HandleCOMMAND(iSender,iNum,sStr,kID);
        }
        else if (iNum == COMMAND_LEASH_SENSOR)
        {
            if (sStr == "Leasher out of range")
            {// particle script sensor lost the leasher... stop to follow
                CleanUp();
            }
            else if (sStr == "Leasher in range")
            {// particle script sensor found the leasher again, restart to follow
                llTargetRemove(g_iTargetHandle);
                g_vPos = llList2Vector(llGetObjectDetails(g_kLeashedTo,[OBJECT_POS]),0);
                g_iTargetHandle = llTarget(g_vPos, g_fLength);
            }
            return;
        }        
    } 
    

   sensor(integer iSense)
    {
        //debug((string)llGetFreeMemory( ));
        integer iLoop;
        string sPrompt;
        if ((g_iSensorMode >= SENSORMODE_FIND_TARGET_FOR_LEASH_MENU) && (g_iSensorMode <= SENSORMODE_FIND_TARGET_FOR_POST_MENU))
        {
            if (g_iSensorMode == SENSORMODE_FIND_TARGET_FOR_FOLLOW_MENU)
                sPrompt = "Pick someone/thing to follow."; 
            else if(g_iSensorMode == SENSORMODE_FIND_TARGET_FOR_LEASH_MENU)
                sPrompt = "Pick someone/thing to leash to.";  
            else if(g_iSensorMode == SENSORMODE_FIND_TARGET_FOR_POST_MENU)
                sPrompt = "Pick the object that you would like the sub to be leashed to.  If it's not in the list, have the sub move closer and try again.\n";
            
            list lButtons = []; // just used for menu building
            for (iLoop = 0; iLoop < iSense; iLoop++)
            {
                if((llDetectedName(iLoop) != "Object") ||  (g_iSensorMode < SENSORMODE_FIND_TARGET_FOR_POST_MENU))
                    lButtons += [llDetectedKey(iLoop)];
                
            }
            g_kDialogID = Dialog(g_kMenuUser, sPrompt, lButtons, [UPMENU], 0);
        }
        else if ((g_iSensorMode >= SENSORMODE_FIND_TARGET_FOR_LEASH_CHAT) && (g_iSensorMode <= SENSORMODE_FIND_TARGET_FOR_POST_CHAT))        
        {
            if (g_iSensorMode == SENSORMODE_FIND_TARGET_FOR_FOLLOW_CHAT)
                "Could not find '" + g_sTmpName + "' to follow.";
            else
                "Could not find '" + g_sTmpName + "' to leash to.";
                
            // Loop through detected avs, seeing if one matches tmpname
            for (iLoop = 0; iLoop < iSense; iLoop++)
            {
                string sName = llDetectedName(iLoop);
                if (startswith(llToLower(sName), llToLower(g_sTmpName)))
                {
                    g_kLeashedTo = llDetectedKey(iLoop);
                    if (g_iSensorMode == SENSORMODE_FIND_TARGET_FOR_FOLLOW_CHAT)
                    {
                        g_bFollowMode = TRUE;
                        LeashTo(g_kLeashedTo, g_kCmdGiver, g_iLastRank, ["collar", "handle"]);
                        //SayFollow(g_kLeashedTo, g_kCmdGiver, g_iLastRank);
                    }
                    else if (CheckCommandAuth(g_kCmdGiver, g_iLastRank))
                    {
                        if (g_iSensorMode == SENSORMODE_FIND_TARGET_FOR_LEASH_CHAT)
                            LeashTo(g_kLeashedTo, g_kCmdGiver, g_iLastRank, ["collar", "handle"]);
                        else if (g_iSensorMode == SENSORMODE_FIND_TARGET_FOR_POST_CHAT)
                            LeashTo(g_kLeashedTo, g_kCmdGiver, g_iLastRank, ["collar", "post"]);
                    }
                    return;
                }
            }
            // No match found -
            Notify(g_kCmdGiver, "Could not find '" + g_sTmpName + "' to follow.", FALSE);
        } 
    }
    
    no_sensor()
    {
        // Nothing found close enough to leash onto, tell menuuser
        Notify(g_kMenuUser, "Unable to find any nearby targets.", FALSE);
        if (g_iSensorMode >= SENSORMODE_FIND_TARGET_FOR_LEASH_MENU && g_iReturnMenu)
            LeashMenu(g_kMenuUser);
    }        
    
    at_target(integer iNum, vector vTarget, vector vMe)
    {
        g_iUnixTime = llGetUnixTime();
        llStopMoveToTarget();
        llTargetRemove(g_iTargetHandle);
        g_vPos = llList2Vector(llGetObjectDetails(g_kLeashedTo,[OBJECT_POS]),0);
        g_iTargetHandle = llTarget(g_vPos, g_fLength);
        if(g_iJustMoved)
        {
            turnToTarget( llList2Vector(llGetObjectDetails(g_kLeashedTo,[OBJECT_POS]),0));
            g_iJustMoved = 0;
        }   
    }
    
    not_at_target()
    {
        g_iJustMoved = 1;
        g_iUnixTime = llGetUnixTime();
        // i ran into a problem here which seems to be "speed" related, specially when using the menu to unleash this event gets triggered together or just after the CleanUp() function
        //to prevent to get stay in the target events i added a check on g_kLeashedTo is NULL_KEY
        if(g_kLeashedTo)
        {
            vector vNewPos = llList2Vector(llGetObjectDetails(g_kLeashedTo,[OBJECT_POS]),0);
            //llStopMoveToTarget();
            if (g_vPos != vNewPos)
            {
                llTargetRemove(g_iTargetHandle);
                g_vPos = vNewPos;
                g_iTargetHandle = llTarget(g_vPos, g_fLength);
            }
            if (g_vPos != ZERO_VECTOR)
            {
                //only at target
               /* if (!(llGetAgentInfo(g_kWearer) & AGENT_SITTING))
                {
                    if ((g_iUnixTime + 2) >= llGetUnixTime())
                    {
                        turnToTarget(g_vPos);
                    }
                }*/
                llMoveToTarget(g_vPos,0.7);
            }
            else
            {
                llStopMoveToTarget();
            }
        }
        else
        {
            Unleash(g_kLeashedTo);
        }
    }
  
    run_time_permissions(integer iPerm)
    {
        if (iPerm & PERMISSION_TAKE_CONTROLS)
        {
            //disbale all controls but left mouse button (for stay cmd)
            llTakeControls(CONTROL_ROT_LEFT | CONTROL_ROT_RIGHT | CONTROL_LBUTTON | CONTROL_ML_LBUTTON, FALSE, FALSE);
        }
    }
}