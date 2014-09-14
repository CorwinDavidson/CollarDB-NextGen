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

integer g_iReady = FALSE; // Default Settings have been loaded?
integer g_iUseDB = FALSE; // Use the Online Database?
integer g_iRemoteOn = FALSE;
integer g_iOnLine = FALSE;


integer g_iRemenu=FALSE;    // should the menu appear after the link message is handled?


string g_sHTTPDB = "http://nextgen2.collardb.com/";  //URL to Database

string g_sCard = "~defaultsettings";

key g_kDataID; 
key g_kAllID;

integer g_iLine;
integer g_iScriptCount;

list g_lDefaultCache;
list g_lSettingsCache;

list g_lRequestQueue;

list g_lTokenIDs;
list g_lDeleteIDs;

string BASE_ERROR_MESSAGE = "An error has occurred. To find out more about this error go to http://www.collardb.com/static/ErrorMessages If you get this a lot, please open a ticket at http://bugs.collardb.com \n";

string ALLTOKEN = "all";

string g_sParentMenu = "Help/Debug";
string g_sSyncFromDB = "Sync<-DB";
//string synctodb = "Sync<-DB"; //we still lack the subsystem for requesting settings from all scripts
string DUMPCACHE = "Dump Cache";
string g_sOnLineButton; // will be initialized after

string g_sOnLineON = "(*)Online";
string g_sOnLineOFF = "( )Online";

string WIKI ="Online Guide";
string WIKI_URL = "http://www.collardb.com/static/UserDocumentation";

list g_lKeep_on_Cleanup=["owner","secowners","openaccess","group","groupname","rlvon","locked","prefix","channel"]; 

$import lib.MessageMap.lslm ();
$import lib.CommonFunctions.lslm ();

//  HTTPDB Functions
SETTING_Query( string sAction, string sName, string sValue )
{
    g_lTokenIDs += [sName, llHTTPRequest( g_sHTTPDB + "db/" + sName, [HTTP_METHOD, sAction], sValue )];
    llSleep(1.0);//sleep added to prevent hitting the sim's http throttle limit
}

ready()
{
    llSleep(1.0);

    // send the values stored in the cache
    SendValues();

    // and store the number of scripts
    g_iScriptCount=llGetInventoryNumber(INVENTORY_SCRIPT);

    //tell the world about our menu button
    if (g_iOnLine) 
        g_sOnLineButton=g_sOnLineON;
    else 
        g_sOnLineButton=g_sOnLineOFF;
    MenuResponse();

    //resend any requests that came while we weren't looking
    integer n;
    integer iStop = llGetListLength(g_lRequestQueue);
    for (n = 0; n < iStop; n = n + 3)
    {
        llMessageLinked(LINK_SET, (integer)llList2String(g_lRequestQueue, n), llList2String(g_lRequestQueue, n + 1), (key)llList2String(g_lRequestQueue, n + 2));
    }
    g_lRequestQueue = [];
    g_iReady = TRUE;
}

DumpCache(string sWichCache)
{
    list lCache;
    string sOut;
    if (sWichCache == "local")
    {
        lCache=g_lSettingsCache;
        sOut = "Local Settings Cache: \n";
    }
    else
    {
        lCache=g_lSettingsCache;
        sOut = "DB Settings Cache: \n";
    }


    integer n;
    integer iStop = llGetListLength(lCache);

    for (n = 0; n < iStop; n = n + 2)
    {
        //handle strlength > 1024
        string sAdd = llList2String(lCache, n) + "=" + llList2String(lCache, n + 1) + "\n";
        if (llStringLength(sOut + sAdd) > 1024)
        {
            //spew and clear
            llWhisper(0, "\n" + sOut);
            sOut = sAdd;
        }
        else
        {
            //keep adding
            sOut += sAdd;
        }
    }
    llWhisper(0, "\n" + sOut);
}

SendValues()
{
    //loop through all the settings and defaults we've got
    //settings first
    integer n;
    integer iStop = llGetListLength(g_lSettingsCache);
    for (n = 0; n < iStop; n = n + 2)
    {
        string sToken = llList2String(g_lSettingsCache, n);
        string sValue = llList2String(g_lSettingsCache, n + 1);
        llMessageLinked(LINK_SET, SETTING_RESPONSE, sToken + "=" + sValue, NULL_KEY);
    }

    //now loop through g_lDefaultCache, sending only if there's not a corresponding token in g_lSettingsCache
    iStop = llGetListLength(g_lDefaultCache);
    for (n = 0; n < iStop; n = n + 2)
    {
        string sToken = llList2String(g_lDefaultCache, n);
        string sValue = llList2String(g_lDefaultCache, n + 1);
        if (!CacheValExists(g_lSettingsCache, sToken))
        {
            llMessageLinked(LINK_SET, SETTING_RESPONSE, sToken + "=" + sValue, NULL_KEY);
        }
    }

    //and now loop through g_lSettingsCache
    iStop = llGetListLength(g_lSettingsCache);
    for (n = 0; n < iStop; n = n + 2)
    {
        string sToken = llList2String(g_lSettingsCache, n);
        string sValue = llList2String(g_lSettingsCache, n + 1);
        llMessageLinked(LINK_SET, SETTING_RESPONSE, sToken + "=" + sValue, NULL_KEY);
        Debug("sent local: " + sToken + "=" + sValue);
    }
    llMessageLinked(LINK_SET, SETTING_RESPONSE, "settings=sent", NULL_KEY);//tells scripts everything has be sentout
}

init()
{
	// Prep Prim to give maximum data storage
    if (llGetNumberOfSides() < 6)
    {
        llSetLinkPrimitiveParamsFast(LINK_THIS,[PRIM_TYPE,PRIM_TYPE_SPHERE,PRIM_HOLE_DEFAULT,<0,.995,0>,0.001,<0,0,0>,<0,1,0>]);
    }
        
	g_lCacheTemplate =[""];
	
    if (g_kWearer == NULL_KEY)
    { //if we just started, save owner key
        g_kWearer = llGetOwner();
    }
    else if (g_kWearer != llGetOwner())
    {//we've changed hands.  reset script
        llResetScript();
    }

     g_lDefaultCache = []; //in case we just switched from the ready state, clean this now to avoid duplicates.
    if (llGetInventoryType(g_sCard) == INVENTORY_NOTECARD)
    {
        g_iLine = 0;
        g_kDataID = llGetNotecardLine(g_sCard, g_iLine);
    }
}

// pragma inline
HandleMENU(integer iSender, integer iNum, string sStr, key kID)
{
    if (iNum == MENU_SUBMENU)
    {
    	integer iHasAuth = CheckAuth(llDetectedKey(0),COMMAND_WEARER,COMMAND_OWNER,FALSE);
        if (sStr == g_sSyncFromDB)
        {
            //notify that we're refreshing
            Notify(kID, "Refreshing settings from web database.", TRUE);
            llMessageLinked(LINK_SET, MENU_SUBMENU, g_sParentMenu, kID);
            init();
        }
        else if (sStr == DUMPCACHE)
        {
            llMessageLinked(LINK_SET, COMMAND_NOAUTH, "cachedump", kID);
            llMessageLinked(LINK_SET, MENU_SUBMENU, g_sParentMenu, kID);
        }
        else if (sStr == g_sOnLineButton)
        {
            g_iRemenu = TRUE;
            if (g_iOnLine)
                llMessageLinked(LINK_SET, COMMAND_NOAUTH, "offline", kID);
            else 
                llMessageLinked(LINK_SET, COMMAND_NOAUTH, "online", kID);
        }
        else if (sStr == WIKI)
        {
            g_iRemenu = TRUE;
            llMessageLinked(LINK_SET, COMMAND_NOAUTH, "wiki", kID);
        }
    }
    else if (iNum == MENU_REQUEST && sStr == g_sParentMenu)
    {
		MenuResponse();
    }
}

// pragma inline    
MenuResponse()
{
    //            llMessageLinked(LINK_SET, MENUNAME_RESPONSE, g_sParentMenu + "|" + synctodb, NULL_KEY);
    llMessageLinked(LINK_SET, MENU_RESPONSE, g_sParentMenu + "|" + g_sSyncFromDB, NULL_KEY);
    llMessageLinked(LINK_SET, MENU_RESPONSE, g_sParentMenu + "|" + DUMPCACHE, NULL_KEY);
    llMessageLinked(LINK_SET, MENU_RESPONSE, g_sParentMenu + "|" + g_sOnLineButton, NULL_KEY);
    llMessageLinked(LINK_SET, MENU_RESPONSE, g_sParentMenu + "|" + WIKI, NULL_KEY);
}

// pragma inline
HandleCOMMAND(integer iSender, integer iNum, string sStr, key kID)
{
   if ( iNum <= COMMAND_OWNER && iNum >= COMMAND_WEARER)
    {
        if (sStr == "wiki")          // open the wiki page
        {
            remenu(kID);
            llLoadURL(kID, "Read the online documentation, see the release note, get tips and infos for designers or report bugs on our website.", WIKI_URL);
        }
        
    }
    else if (iNum == COMMAND_OWNER || ((iNum < COMMAND_OWNER) && (iNum >= COMMAND_WEARERLOCKEDOUT) && (kID == g_kWearer)))
    {
        if (sStr == "cachedump")
        {
            DumpCache("db");
            DumpCache("local");
        }
        else if (sStr == "reset" || sStr == "runaway")
        {
            g_lSettingsCache = [];
            g_lSettingsCache = [];
            if (g_iOnLine)
            {
                llHTTPRequest( g_sHTTPDB + "db/" + ALLTOKEN+"?d=TRUE", [HTTP_METHOD, "POST"], "");
                llSleep(2.0);
                //save that we got a reset command:
                llMessageLinked(LINK_SET, SETTING_SAVE, "lastReset=" + (string)llGetUnixTime(), "");
            }
        }
        else if (sStr == "remoteon")
        {
            if (g_iOnLine)
            {
                g_iRemoteOn = TRUE;
                Notify(kID, "Remote On.",TRUE);
                llMessageLinked(LINK_SET, SETTING_SAVE, "remoteon=1", NULL_KEY);
            }
            else Notify(kID, "Sorry, remote control only works in online mode.", FALSE);
        }
        else if (sStr == "remoteoff")
        {
            //wearer can't turn remote off
            if (iNum != COMMAND_OWNER)
            {
                Notify(kID, "Sorry, only the primary owner can turn off the remote.",FALSE);
            }
            else
            {
                g_iRemoteOn = FALSE;
                Notify(kID, "Remote Off.", TRUE);
                llMessageLinked(LINK_SET, SETTING_SAVE, "remoteon=0", NULL_KEY);
            }
        }
        else if ((sStr == "online") || (sStr == "offline"))
        {
            //wearer can't change online mode
            if (iNum != COMMAND_OWNER || kID != g_kWearer)
            {
                Notify(kID, "Sorry, only a self-owned wearer can enable " + sStr + " mode.", FALSE);
            }
            else
            {
                g_iOnLine = (~g_iOnLine);
                llMessageLinked(LINK_SET, MENU_REMOVE, g_sParentMenu + "|" + g_sOnLineButton, NULL_KEY);
                llMessageLinked(LINK_SET, SETTING_RESPONSE,"online=" + (string)g_iOnLine,NULL_KEY);
                if (sStr == "offline")
                {
                    g_sOnLineButton = g_sOnLineOFF;
                    llMessageLinked(LINK_SET, MENU_RESPONSE, g_sParentMenu + "|" + g_sOnLineButton, NULL_KEY);
                    Notify(kID, "Online mode disabled.", TRUE);
                }
                else
                {
                    Notify(kID, "Online mode enabled. Restoring settings from database.", TRUE);
                    init();
                }
            }
            remenu(kID);
        }
        else if (sStr == "cleanup")
            // delete vaues stored in the DB and restores thr most important setting
        {
            if (!g_iOnLine)
                // if we are offline, we dont do anything
            {
                llOwnerSay("Your collar is offline mode, so you cannot perform a cleanup of the HTTP database.");
            }
            else
            {
                // we are online, so we inform the user
                llOwnerSay("The settings from the database will now be deleted. After that the settings for the following values will restored, but you might need to restore settings for badword, colors, textures etc.: "+llList2CSV(g_lKeep_on_Cleanup)+".\nThe cleanup may take about 1 minute.");
                // delete the values fromt he db and take a nap
                llHTTPRequest( g_sHTTPDB + "db/" + ALLTOKEN+"?d=TRUE", [HTTP_METHOD, "POST"], "");
                llSleep(3.0);
                // before we dbcache the settings to be restored
                integer m=llGetListLength(g_lKeep_on_Cleanup);
                integer i;
                string t;
                string v;
                list tempg_lSettingsCache;
                for (i=0;i<m;i++)
                {
                    t=llList2String(g_lKeep_on_Cleanup,i);
                    if (CacheValExists(g_lSettingsCache, t))
                    {
                        tempg_lSettingsCache+=[t,GetCacheVal(g_lSettingsCache, t,0)];
                    }
                }
                // now we can clean the dbcache
                g_lSettingsCache=[];
                // and restore the values we
                m=llGetListLength(tempg_lSettingsCache);
                for (i=0;i<m;i=i+2)
                {
                    t=llList2String(tempg_lSettingsCache,i);
                    v=llList2String(tempg_lSettingsCache,i+1);
                    SETTING_Query("PUT",t, v);
                    g_lSettingsCache = SetCacheVal(g_lSettingsCache, t, v,0);
                }
                llOwnerSay("The cleanup has been performed. You can use the collar normaly again, but some of your previous settings may need to be redone. Resetting now.");
                llMessageLinked(LINK_SET, SETTING_SAVE, "lastReset=" + (string)llGetUnixTime(), "");

                llSleep(1.0);

                llMessageLinked(LINK_SET, COMMAND_OWNER, "resetscripts", kID);
            }

        }
    }
}

remenu(key kID)
{
    if (g_iRemenu) 
    {
        g_iRemenu=FALSE; 
        llMessageLinked(LINK_SET, MENU_SUBMENU, g_sParentMenu, kID);
    }
}

default
{
    state_entry()
    {
        init();
    }

    on_rez(integer iParam)
    {
        init();
    }
    
    link_message(integer iSender, integer iMsgID, string sMsg, key kID)
    {
            if ((iMsgID >= SETTING_SAVE) && (iMsgID <= SETTING_DELETE))
            {
                if (g_iReady)
                {
                    string sToken = llJsonGetValue( sMsg, ["token"] );
                    string sValue = llJsonGetValue( sMsg, ["value"] );
                    integer iCache = (integer)llJsonGetValue( sMsg, ["cache"] );
                    if (iMsgID == SETTING_SAVE)
                    {
                        if (g_iUseDB) SETTING_Query("PUT",sToken,sValue);
                        g_lSettingsCache = SetCacheVal(g_lSettingsCache, sToken, sValue,0);
                    }
                    else if (iMsgID == SETTING_REQUEST)
                    {
                        //check the dbcache for the token
                        if (CacheValExists(g_lSettingsCache, sToken))
                        {
                            llMessageLinked(LINK_SET, SETTING_RESPONSE, sToken + "=" + GetCacheVal(g_lSettingsCache, sToken,0), NULL_KEY);
                        }
                        else if (CacheValExists(g_lDefaultCache, sToken))
                        {
                            llMessageLinked(LINK_SET, SETTING_RESPONSE, sToken + "=" + GetCacheVal(g_lDefaultCache, sToken,0), NULL_KEY);
                        }
                        else
                        {
                            llMessageLinked(LINK_SET, SETTING_EMPTY, sToken, NULL_KEY);
                        }
                    }
                    else if (iMsgID == SETTING_REQUEST_NOCACHE)
                    {
                        //request the token
                        if (g_iUseDB) SETTING_Query("GET",sToken,"");
                    }
                    else if (iMsgID == SETTING_DELETE)
                    {
                        g_lSettingsCache = DelCacheVal(g_lSettingsCache, sToken,0);
                        if (g_iUseDB) SETTING_Query("DELETE",sToken,"");
                    }
                    else if (iMsgID == SETTING_RESPONSE && sToken == "remoteon")
                    {
                        g_iRemoteOn = (integer)sValue;
                    }
                }
                else
                {
                    if (iMsgID == SETTING_REQUEST || iMsgID == SETTING_SAVE || iMsgID == SETTING_DELETE)
                    {
                        //we don't want to process these yet so queue them til done reading the notecard
                        g_lRequestQueue += [iMsgID, sMsg, kID];
                    }
                }
            }    
    
    }


    http_response(key kID, integer iStatus, list lMeta, string sBody)
    {
        string sOwners;
        if (kID == g_kAllID)
        {
            if (iStatus == 200)
            {
                //got all settings page, parse it
                g_lSettingsCache = [];
                list lSettings = llJson2List( sBody );
                integer iStop = llGetListLength(lSettings);
                integer n;
                for (n = 0; n < iStop; n = n + 2)
                {
                    g_lSettingsCache = SetCacheVal(g_lSettingsCache, llList2String(lSettings,n), llList2String(lSettings,n + 1),0);
                }
                if (llStringLength(sBody)>=2040)
                {
                    string sPrefix;
                    if (CacheValExists(g_lSettingsCache, "prefix"))
                    {
                        sPrefix=GetCacheVal(g_lSettingsCache, "prefix",0);
                    }
                    else
                    {
                        string s=llKey2Name(g_kWearer);
                        integer i=llSubStringIndex(s," ")+1;

                        sPrefix=llToLower(llGetSubString(s,0,0)+llGetSubString(s,i,i));
                    }
                    llOwnerSay("ATTENTION: Settings loaded from web database, but the answer was so long that SL probably truncated it. This means, that your settings are probably not correctly saved anymore. This usually happens when you tested a lot of different collars. To fix this, you can type \""+sPrefix+"cleanup\" in open chat, this will clear ALL your saved values but the owners, lock and RLV. Sorry for inconvenience.");
                }
                else
                {
                    if (sOwners == "")
                    {
                        llOwnerSay("Collar ready. You are unowned.");
                    }
                    else
                    {
                        llOwnerSay("Collar ready. You are owned by: " + llList2CSV(llList2ListStrided(llParseString2List("dummy," + sOwners,[","],[]),1,-1,2)) + ".");
                    }
                }
            }
            else
            {
                llOwnerSay("Unable to contact web database.  Using defaults and cached values.");
                Notify(g_kWearer, BASE_ERROR_MESSAGE+"Start ERROR:"+(string)iStatus+" b:"+sBody, TRUE);
            }
            sOwners = "";
            ready();
        }
        else
        {
            integer iIndex = llListFindList(g_lTokenIDs, [kID]);
            if ( iIndex != -1 )
            {
                string sToken = llList2String(g_lTokenIDs, iIndex - 1);
                if (iStatus == 200)
                {
                    string sOut = sToken + "=" + sBody;
                    llMessageLinked(LINK_SET, SETTING_RESPONSE, sOut, NULL_KEY);
                    g_lSettingsCache = SetCacheVal(g_lSettingsCache, sToken, sBody,0);
                }
                else if (iStatus == 404)
                {
                    // Value was not in HTTPDB, Send Default Value if it exists
                    if (CacheValExists(g_lDefaultCache,sToken))
                    {
                        llMessageLinked(LINK_SET, SETTING_RESPONSE, sToken + "=" + GetCacheVal(g_lDefaultCache,sToken,0), NULL_KEY);                       
                    }
                    else
                    {
                        llMessageLinked(LINK_SET, SETTING_EMPTY, sToken, NULL_KEY); 
                    }
                }
                else
                {
                    Notify(g_kWearer, BASE_ERROR_MESSAGE+"Token ERROR:"+(string)iStatus+" b:"+sBody, TRUE);
                }
                //remove token, id from list
                g_lTokenIDs = llDeleteSubList(g_lTokenIDs, iIndex - 1, iIndex);
            }
            else if (iStatus < 300 )
            {
                //nothing
                iIndex = llListFindList(g_lDeleteIDs, [kID]);
                if (iIndex != -1)
                {
                    g_lDeleteIDs = llDeleteSubList(g_lDeleteIDs, iIndex, iIndex);
                }
            }
            else
            {
                iIndex = llListFindList(g_lDeleteIDs, [kID]);
                if (iIndex != -1)
                {
                    g_lDeleteIDs = llDeleteSubList(g_lDeleteIDs, iIndex, iIndex);
                    if (iStatus == 404)
                    {
//#mdebug info	                    	
                        Debug("404 on delete");
//#enddebug	                        
                        return;//this is not an error
                    }
                }
                Notify(g_kWearer, BASE_ERROR_MESSAGE+"ERROR:"+(string)iStatus+" b:"+sBody, TRUE);
            }
        }
        
    }
    
    
    dataserver(key kID, string sData)
    {
        if (kID == g_kDataID)
        {
            if (sData != EOF)
            {
                sData = llStringTrim(sData, STRING_TRIM_HEAD);
                if (llGetSubString(sData, 0, 0) != "#")
                {
                    integer iIndex = llSubStringIndex(sData, "=");
                    string sToken = llGetSubString(sData, 0, iIndex - 1);
                    string sValue = llGetSubString(sData, iIndex + 1, -1);
                    if (sToken=="online")
                    {
                        g_iOnLine = (integer) sValue;
                    }
                    else if (sToken=="HTTPDB")
                    {
                        g_sHTTPDB = sValue;
                    }
                    g_lDefaultCache = SetCacheVal(g_lDefaultCache,sToken,sValue,0);
                }
                g_iLine++;
                g_kDataID = llGetNotecardLine(g_sCard, g_iLine);
            }
            else
            {
                //done reading notecard, switch to ready state
                if (g_iOnLine) 
                {
                    g_kAllID = llHTTPRequest(g_sHTTPDB + "db/" + ALLTOKEN, [HTTP_METHOD, "GET"], "");
                }
                else
                {
                    llOwnerSay("Running in offline mode. Using defaults and dbcached values.");
                   // ready();
                }
            }
        }
    }    
    changed(integer iChange)
    {
        if ((iChange == CHANGED_INVENTORY) && (g_iScriptCount != llGetInventoryNumber(INVENTORY_SCRIPT)))
        {
            // number of scripts changed, resend values and store new number
          //  SendValues();
            g_iScriptCount=llGetInventoryNumber(INVENTORY_SCRIPT);
        }    
        
        if (iChange & CHANGED_OWNER)
        {
            llResetScript();
        }
    }
    
}
