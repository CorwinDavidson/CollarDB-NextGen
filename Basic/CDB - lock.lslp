/*--------------------------------------------------------------------------------**
**  File: CDB - lock                                                              **
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
integer g_iDebug = FALSE;

key g_kWearer;
list g_lOwners;

string g_sParentMenu = "Main";
string LOCK = "*Lock*";
string UNLOCK = "*Unlock*";
integer g_iRemenu=FALSE;

list g_lLOCKSTATE = ["*Lock*","*Unlock*"];
list g_lYorN = ["y","n"];
integer g_iLocked = FALSE;

string g_sLockPrimName="Lock";           // Description for lock elements to recognize them (Legacy: Kept for compatability)
string g_sOpenLockPrimName="OpenLock";    // Prim description of elements that should be shown when unlocked
string g_sClosedLockPrimName="ClosedLock"; // Prim description of elements that should be shown when locked
list g_lClosedLockElements;              //to store the locks prim to hide or show 
list g_lOpenLockElements;                //to store the locks prim to hide or show 

//added to prevent altime attach messages
integer g_bDetached = FALSE;


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
integer COMMAND_SAFEWORD        = 0xCDB510;
integer COMMAND_WEARERLOCKEDOUT = 0xCDB521;

integer POPUP_HELP              = -0xCDB001;      

integer HTTPDB_SAVE             = 0xCDB200;     // scripts send messages on this channel to have settings saved to httpdb
                                                // str must be in form of "token=value"
integer HTTPDB_REQUEST          = 0xCDB201;     // when startup, scripts send requests for settings on this channel
integer HTTPDB_RESPONSE         = 0xCDB202;     // the httpdb script will send responses on this channel
integer HTTPDB_DELETE           = 0xCDB203;     // delete token from DB
integer HTTPDB_EMPTY            = 0xCDB204;     // sent by httpdb script when a token has no value in the db
integer HTTPDB_REQUEST_NOCACHE  = 0xCDB205;

integer LOCALSETTING_SAVE       = 0xCDB250;
integer LOCALSETTING_REQUEST    = 0xCDB251;
integer LOCALSETTING_RESPONSE   = 0xCDB252;
integer LOCALSETTING_DELETE     = 0xCDB253;
integer LOCALSETTING_EMPTY      = 0xCDB254;

integer MENUNAME_REQUEST        = 0xCDB300;
integer MENUNAME_RESPONSE       = 0xCDB301;
integer SUBMENU                 = 0xCDB302;
integer MENUNAME_REMOVE         = 0xCDB303;

integer RLV_CMD                 = 0xCDB600;
integer RLV_REFRESH             = 0xCDB601;     // RLV plugins should reinstate their restrictions upon receiving this message.
integer RLV_CLEAR               = 0xCDB602;     // RLV plugins should clear their restriction lists upon receiving this message.
integer RLVR_CMD                = 0xCDB612;

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


NotifyOwners(string sMsg)
{
    integer n;
    integer stop = llGetListLength(g_lOwners);
    for (n = 0; n < stop; n += 2)
    {
        // Cleo: Stop IMs going wild
        if (g_kWearer != llGetOwner())
        {
            llResetScript();
            return;
        }
        else
            Notify((key)llList2String(g_lOwners, n), sMsg, FALSE);
    }
}

string GetPSTDate()
{ //Convert the date from UTC to PST if GMT time is less than 8 hours after midnight (and therefore tomorow's date).
    string DateUTC = llGetDate();
    if (llGetGMTclock() < 28800) // that's 28800 seconds, a.k.a. 8 hours.
    {
        list DateList = llParseString2List(DateUTC, ["-", "-"], []);
        integer year = llList2Integer(DateList, 0);
        integer month = llList2Integer(DateList, 1);
        integer day = llList2Integer(DateList, 2);
        day = day - 1;
        return (string)year + "-" + (string)month + "-" + (string)day;
    }
    return llGetDate();
}

string GetTimestamp() // Return a string of the date and time
{
    integer t = (integer)llGetWallclock(); // seconds since midnight

    return GetPSTDate() + " " + (string)(t / 3600) + ":" + PadNum((t % 3600) / 60) + ":" + PadNum(t % 60);
}

string PadNum(integer value)
{
    if(value < 10)
    {
        return "0" + (string)value;
    }
    return (string)value;
}

BuildLockElementList()
{
    integer n;
    integer iLinkCount = llGetNumberOfPrims();
    list lParams;

    // clear list just in case
    g_lOpenLockElements = [];
    g_lClosedLockElements = [];

    //root prim is 1, so start at 2
    for (n = 2; n <= iLinkCount; n++)
    {
        lParams=llParseString2List((string)llGetObjectDetails(llGetLinkKey(n), [OBJECT_DESC]), ["~"], []);
        if (llList2String(lParams, 0)==g_sLockPrimName || llList2String(lParams, 0)==g_sClosedLockPrimName)
        {
            g_lClosedLockElements += [n];
        }
        else if (llList2String(lParams, 0)==g_sOpenLockPrimName) 
        {
            g_lOpenLockElements += [n];
        }
    }
}

SetLockElementAlpha() 
{
    //loop through stored links, setting alpha if element type is lock
    integer n;
    float fAlpha;
    if (g_iLocked) fAlpha = 1.0; else fAlpha = 0.0;
    integer iLinkElements = llGetListLength(g_lOpenLockElements);
    for (n = 0; n < iLinkElements; n++)
    {
        llSetLinkAlpha(llList2Integer(g_lOpenLockElements,n), 1.0 - fAlpha, ALL_SIDES);
    }
    iLinkElements = llGetListLength(g_lClosedLockElements);
    for (n = 0; n < iLinkElements; n++)
    {
        llSetLinkAlpha(llList2Integer(g_lClosedLockElements,n), fAlpha, ALL_SIDES);
    }
}

Lock()
{

    g_iLocked = TRUE;
    llMessageLinked(LINK_SET, HTTPDB_SAVE, "locked=1", NULL_KEY);
    llMessageLinked(LINK_SET, RLV_CMD, "detach=n", NULL_KEY);
    llMessageLinked(LINK_SET, MENUNAME_RESPONSE, g_sParentMenu + "|" + llList2String(g_lLOCKSTATE,g_iLocked), NULL_KEY);    
    llPlaySound("abdb1eaa-6160-b056-96d8-94f548a14dda", 1.0);
    llMessageLinked(LINK_SET, MENUNAME_REMOVE, g_sParentMenu + "|" + llList2String(g_lLOCKSTATE,(~g_iLocked)), NULL_KEY);
    SetLockElementAlpha();
}

Unlock()
{
    g_iLocked = FALSE;
    llMessageLinked(LINK_SET, HTTPDB_DELETE, "locked", NULL_KEY);
    llMessageLinked(LINK_SET, RLV_CMD, "detach=y", NULL_KEY);
    llMessageLinked(LINK_SET, MENUNAME_RESPONSE, g_sParentMenu + "|" + llList2String(g_lLOCKSTATE,g_iLocked), NULL_KEY);
    llPlaySound("ee94315e-f69b-c753-629c-97bd865b7094", 1.0);
    llMessageLinked(LINK_SET, MENUNAME_REMOVE, g_sParentMenu + "|" + llList2String(g_lLOCKSTATE,(~g_iLocked)), NULL_KEY);
    SetLockElementAlpha(); 
}

/*---------------//
//  HANDLERS     //
//---------------*/

HandleHTTPDB(integer iSender, integer iNum, string sStr, key kID)
{
        if ((iNum == HTTPDB_RESPONSE) || (iNum == HTTPDB_SAVE))
        {
            list lParams = llParseString2List(sStr, ["="], []);
            string sToken = llList2String(lParams, 0);
            string sValue = llList2String(lParams, 1);
            if ((sToken == "locked") && (iNum == HTTPDB_RESPONSE))
            {
                g_iLocked = (integer)sValue;
                llMessageLinked(LINK_SET, MENUNAME_RESPONSE, g_sParentMenu + "|" + llList2String(g_lLOCKSTATE,g_iLocked), NULL_KEY);
                llMessageLinked(LINK_SET, MENUNAME_REMOVE, g_sParentMenu + "|" + llList2String(g_lLOCKSTATE,(~g_iLocked)), NULL_KEY);
                llMessageLinked(LINK_SET, RLV_CMD, "detach=" + llList2String(g_lYorN,g_iLocked), NULL_KEY);
                SetLockElementAlpha(); 

            }
            else if (sToken == "owner")
            {
                g_lOwners = llParseString2List(sValue, [","], []);
            }
        }

}


HandleMENU(integer iSender, integer iNum, string sStr, key kID)
{
    if (iNum == SUBMENU)
    {
        if (sStr == LOCK)
        {
            g_iRemenu=TRUE;
            llMessageLinked(LINK_SET, COMMAND_NOAUTH, "lock", kID);
        }
        else if (sStr == UNLOCK)
        {
            g_iRemenu=TRUE;
            llMessageLinked(LINK_SET, COMMAND_NOAUTH, "unlock", kID);
        }
    }
    else if (iNum == MENUNAME_REQUEST && sStr == g_sParentMenu)
    {
        llMessageLinked(LINK_SET, MENUNAME_RESPONSE, g_sParentMenu + "|" + llList2String(g_lLOCKSTATE,g_iLocked), NULL_KEY);
        llMessageLinked(LINK_SET, MENUNAME_REMOVE, g_sParentMenu + "|" + llList2String(g_lLOCKSTATE,(~g_iLocked)), NULL_KEY);
    }
}

HandleCOMMAND(integer iSender, integer iNum, string sStr, key kID)
{
        if ((iNum >= COMMAND_OWNER) && (iNum <= COMMAND_WEARER))
        {
            if (sStr == "settings")
            {
                if (g_iLocked) 
                    Notify(kID, "Locked.", FALSE);
                else 
                    Notify(kID, "Unlocked.", FALSE);
            }
            else if ((sStr == "lock") || (sStr == "unlock"))
            {
                if (sStr == "lock"){
                    if (iNum == COMMAND_OWNER || kID == g_kWearer )
                    {   //primary owners and wearer can lock and unlock. no one else
                        Lock();
                        Notify(kID, "Locked.", FALSE);
                        if (kID!=g_kWearer) 
                            llOwnerSay("Your collar has been locked.");
                    }
                    else
                    {
                        Notify(kID, "Sorry, only primary owners and wearer can lock the collar.", FALSE);
                    }
                }
                else if (sStr == "unlock")
                {
                    if (iNum == COMMAND_OWNER)
                    {  //primary owners can lock and unlock. no one else
                        Unlock();
                        Notify(kID, "Unlocked.", FALSE);
                        if (kID!=g_kWearer) 
                            llOwnerSay("Your collar has been unlocked.");
                    }
                    else
                    {
                        Notify(kID, "Sorry, only primary owners can unlock the collar.", FALSE);
                    }
                }
                remenu(kID);
            }
        }
        else if ((iNum == COMMAND_WEARER || iNum == COMMAND_OWNER ) && (kID==g_kWearer))
        {
            if ((sStr == "reset") || (sStr == "runaway"))
            {
                    g_iRemenu = FALSE;
                    Unlock();
                    llOwnerSay("Your collar has been unlocked.");
            }
        }
 }

HandleRLV(integer iSender, integer iNum, string sStr, key kID)
{
    if ((iNum == RLV_REFRESH) || (iNum == RLV_CLEAR))
    {
        llMessageLinked(LINK_SET, RLV_CMD, "detach=" + llList2String(g_lYorN,g_iLocked), NULL_KEY);
    }
}

remenu(key kID)
{
    if (g_iRemenu) 
    {
        g_iRemenu=FALSE; 
        llMessageLinked(LINK_SET, SUBMENU, g_sParentMenu, kID);
    }
}

/*---------------//
//  MAIN CODE    //
//---------------*/
default
{
    state_entry()
    {   //until set otherwise, wearer is owner
        g_kWearer = llGetOwner();
        BuildLockElementList();
        SetLockElementAlpha(); 
    }

    link_message(integer iSender, integer iNum, string sStr, key kID)
    {
            if ((iNum >= HTTPDB_SAVE) && (iNum <= HTTPDB_REQUEST_NOCACHE))
            {
                HandleHTTPDB(iSender,iNum,sStr,kID);
            }
            else if ((iNum >= MENUNAME_REQUEST) && (iNum <= MENUNAME_REMOVE))
            {
                HandleMENU(iSender,iNum,sStr,kID); 
            }
            else if ((iNum >= RLV_REFRESH) && (iNum <= RLVR_CMD))
            {
                HandleRLV(iSender,iNum,sStr,kID);
            }
            else if ((iNum >= COMMAND_OWNER) && (iNum <= COMMAND_WEARERLOCKEDOUT))
            {
                HandleCOMMAND(iSender,iNum,sStr,kID);
            }
    }    
 
    attach(key kID)
    {
        if (g_iLocked)
        {
            if(kID == NULL_KEY)
            {
                g_bDetached = TRUE;
                NotifyOwners(llKey2Name(g_kWearer) + " has detached me while locked at " + GetTimestamp() + "!");
            }
            else if(g_bDetached)
            {
                NotifyOwners(llKey2Name(g_kWearer) + " has re-atached me at " + GetTimestamp() + "!");
                g_bDetached = FALSE;
            }
        }
    }

    changed(integer iChange)
    {
        if (iChange & CHANGED_OWNER)
        {
            llResetScript();
        }
    }

    on_rez(integer start_param)
    {
        // stop IMs going wild
        if (g_kWearer != llGetOwner())
        {
            llResetScript();
        }
    }

}