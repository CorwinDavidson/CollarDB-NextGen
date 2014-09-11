/*--------------------------------------------------------------------------------**
**  File: CDB - settings                                                          **
** ------------------------------------------------------------------------------ **
**  Version: 6.00.001                                                             **
** ------------------------------------------------------------------------------ **
** Licensed under the GPLv2, with the additional requirement that these scripts   **
** remain "full perms" in Second Life�.  See "CollarDB License" for details.      **
** ------------------------------------------------------------------------------ **
** �2014 CollarDB and Individual Contributors                                     **
**--------------------------------------------------------------------------------*/

integer g_iReady = FALSE; // Default Settings have been loaded?
integer g_iUseDB = FALSE; // Use the Online Database?
integer g_iRemoteOn = FALSE;
integer g_iOnLine = FALSE;

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

$import lib.MessageMap.lslm ();
$import lib.CommonFunctions.lslm ();

//  HTTPDB Functions
HTTPDB_Query( string action, string sName, string sValue )
{
    g_lTokenIDs += [sName, llHTTPRequest( g_sHTTPDB + "db/" + sName, [HTTP_METHOD, "GET"], sValue )];
    llSleep(1.0);//sleep added to prevent hitting the sim's http throttle limit
}

init()
{
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
                        if (g_iUseDB) HTTPDB_Query("PUT",sToken,sValue);
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
                        if (g_iUseDB) HTTPDB_Query("GET",sToken,"");
                    }
                    else if (iMsgID == SETTING_DELETE)
                    {
                        g_lSettingsCache = DelCacheVal(g_lSettingsCache, sToken,0);
                        if (g_iUseDB) HTTPDB_Query("DELETE",sToken,"");
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
           // ready();
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
//@                        Debug("404 on delete");
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
                    SetCacheVal(g_lDefaultCache,sToken,sValue,0);
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
