/*--------------------------------------------------------------------------------**
**  File: CDB - listener                                                          **
** ------------------------------------------------------------------------------ **
**  Version: 6.00.001                                                             **
** ------------------------------------------------------------------------------ **
** Licensed under the GPLv2, with the additional requirement that these scripts   **
** remain "full perms" in Second Life�.  See "CollarDB License" for details.      **
** ------------------------------------------------------------------------------ **
** �2014 CollarDB and Individual Contributors                                     **
**--------------------------------------------------------------------------------*/


integer g_iListenChan = 1;
integer g_iListenChan0 = TRUE;
string g_sPrefix = ".";

integer g_iHUDChan = -1334245234; // channel to be used by any object not from the wearer itself. This channel will be personalized below.
integer g_iInterfaceChannel = -12587429; // channel to be used by attachments. This channel will be personalized below.

integer g_iLockMeisterChan = -8888;

integer g_iChan0Listener;
integer g_iPrivateListener;
integer g_iHUDListener;
integer g_iInterfaceListener;
integer g_iLockMesiterListener;

// new g_sSafeWord
string g_sSafeWord = "SAFEWORD";

string g_sParentMenu = "";

string g_sSeparator = "|";
string g_iAuth;
string UUID;
string g_sCmd;


$import lib.MessageMap.lslm ();
$import lib.CommonVariables.lslm ();
$import lib.CommonFunctions.lslm ();

SetListeners()
{
    llListenRemove(g_iChan0Listener);
    llListenRemove(g_iPrivateListener);
    llListenRemove(g_iLockMesiterListener);
    llListenRemove(g_iInterfaceListener);
    llListenRemove(g_iHUDListener);

    if(g_iListenChan0 == TRUE)
    {
        g_iChan0Listener = llListen(0, "", NULL_KEY, "");
    }
        
    g_iInterfaceListener = llListen(g_iInterfaceChannel, "", "", "");
    g_iPrivateListener = llListen(g_iListenChan, "", NULL_KEY, "");
    g_iHUDListener = llListen(g_iHUDChan, "", NULL_KEY ,"");
    g_iLockMesiterListener = llListen(g_iLockMeisterChan, "", NULL_KEY, (string)g_kWearer + "collar");

}

string AutoPrefix()
{
    list sName = llParseString2List(llKey2Name(g_kWearer), [" "], []);
    return llToLower(llGetSubString(llList2String(sName, 0), 0, 0)) + llToLower(llGetSubString(llList2String(sName, 1), 0, 0));
}

string CollarVersion()
{
    // checks if the version of the collar
    // return the version of the collar or 0.000 if the version could not be detected

    list lParams = llParseString2List(llGetObjectDesc(), ["~"], []);
    string sName = llList2String(lParams, 0);
    string sVersion = llList2String(lParams, 1);

    if (sName == "" || sVersion == "")
    {
        return "0.000";
    }
    else if ((float)sVersion)
    {
        return llGetSubString((string)sVersion,0,4);
    }
    return "0.000";
}


/*---------------//
//  HANDLERS     //
//---------------*/



/*---------------//
//  MAIN CODE    //
//---------------*/
default
{
    state_entry()
    {
        g_kWearer = llGetOwner();
        g_sPrefix = AutoPrefix();
        llMessageLinked(LINK_SET, SETTING_REQUEST, llList2Json( JSON_OBJECT, [ "Token", "prefix" , "Value", g_sPrefix ] ), NULL_KEY);
        g_iHUDChan = GetOwnerChannel(g_kWearer, 0xCDB001); // persoalized channel for this sub
        g_iInterfaceChannel = GetOwnerChannel(g_kWearer, 0xCDB002);
        SetListeners();
        llMessageLinked(LINK_SET, SETTING_REQUEST, llList2Json( JSON_OBJECT, [ "Token", "prefix"]), NULL_KEY);
    }

    attach(key kID)
    {
        integer test = !(kID == NULL_KEY);
        llRegionSayTo(g_kWearer,g_iInterfaceChannel,llList2Json( JSON_OBJECT, ["Token","CollarDB","Value",(string)test]));
        llRegionSayTo(llGetOwner(),0,llList2Json( JSON_OBJECT, ["Token","CollarDB","Value",(string)test]));
    }

    listen(integer sChan, string sName, key kID, string sMsg)
    {
        key kUUID = (key)llJsonGetValue(sMsg,["UUID"]);
        string sCmd = llJsonGetValue(sMsg,["CMD"]);
        // new object/HUD channel block
        if (sChan == g_iHUDChan)
        {
            //check for a ping, if we find one we request auth and answer in LMs with a pong
            if (kUUID==g_kWearer)
            { 
                if (sCmd == "ping")
                {
                    llMessageLinked(LINK_SET, COMMAND_NOAUTH, llList2Json( JSON_OBJECT, [ "CMD", sCmd, "Value", (string)kID ]), llGetOwnerKey(kID));
                }
                // an object wants to know the version, we check if it is allowed to
                else if (sCmd=="version")
                {
                    llMessageLinked(LINK_SET, COMMAND_NOAUTH, llList2Json( JSON_OBJECT, [ "CMD", "objectversion", "Value", (string)kID ]), llGetOwnerKey(kID));
                }
                else
                {
                    llMessageLinked(LINK_SET, COMMAND_OBJECT, sMsg, kID);
                }
            }
            else
            {
                llMessageLinked(LINK_SET, COMMAND_NOAUTH, sMsg, llGetOwnerKey(kID));
            }
        }
        else if (sChan == g_iInterfaceChannel)
        {
            //do nothing if wearer isnt owner of the object
            if (llGetOwnerKey(kID) != g_kWearer) return;

            if (sCmd == "CollarDB?")
            {
                llRegionSayTo(kID,g_iInterfaceChannel, llList2Json( JSON_OBJECT, [ "CMD", "CollarDB", "Value", "Yes" ]));
                return;
            }
            else if (sCmd == "version")
            {
                llRegionSayTo(kID,g_iInterfaceChannel, llList2Json( JSON_OBJECT, [ "CMD", "version", "Value", CollarVersion() ]));
                return;
            }
        }        
        else if (sChan == g_iLockMeisterChan)
        {
            llRegionSayTo(kID,g_iLockMeisterChan,(string)g_kWearer + "collar ok");
        }
        else if((kID == g_kWearer) && ((sMsg == g_sSafeWord)||(sMsg == "(("+g_sSafeWord+"))")))
        { // safeword can be the safeword or safeword said in OOC chat "((SAFEWORD))"
            llMessageLinked(LINK_SET, COMMAND_SAFEWORD, "", NULL_KEY);
            llOwnerSay("You used your safe word, your owner will be notified you did.");
        }
        else
        { //check for our prefix, or *
            if (startswith(sMsg, g_sPrefix))
            {
                //trim
                sMsg = llGetSubString(sMsg, llStringLength(g_sPrefix), -1);
                llMessageLinked(LINK_SET, COMMAND_NOAUTH, sMsg, kID);
            }
            else if (llGetSubString(sMsg, 0, 0) == "*")
            {
                sMsg = llGetSubString(sMsg, 1, -1);
                llMessageLinked(LINK_SET, COMMAND_NOAUTH, sMsg, kID);
            }
            // added # as prefix for all subs around BUT yourself
            else if ((llGetSubString(sMsg, 0, 0) == "#") && (kID != g_kWearer))
            {
                sMsg = llGetSubString(sMsg, 1, -1);
                llMessageLinked(LINK_SET, COMMAND_NOAUTH, sMsg, kID);
            }
        }
    }

    
    link_message(integer iSender, integer iNum, string sMsg, key kID)
    {
        string sToken = llJsonGetValue(sMsg,["Token"]);
        string sCMD = llJsonGetValue(sMsg,["CMD"]);
        string sValue = llJsonGetValue(sMsg,["Value"]);
        if ((iNum >= SETTING_SAVE) && (iNum <= SETTING_EMPTY))
        {
            if (iNum == SETTING_RESPONSE)
            {
                if (sToken == "prefix")
                {
                    //prefix is the only token for which the httpdb will send a blank value, just so that
                    //this script can know it's time to send the helpful popup.
                    g_sPrefix = sValue;
                }
                else if (sToken == "channel")
                {
                    g_iListenChan = (integer)sValue;
                    if (llGetSubString(sValue, llStringLength(sValue) - 5 , -1) == "FALSE")
                    {
                        g_iListenChan0 = FALSE;
                    }
                    else
                    {
                        g_iListenChan0 = TRUE;
                    }
                }
                else if (sToken == "safeword")
                {
                    g_sSafeWord = sValue;
                }
                SetListeners();
            }
            else if (iNum == SETTING_EMPTY && sToken == "prefix")
            {
                g_sPrefix = AutoPrefix();
            }
        }
        else if ((iNum >= MENU_REQUEST) && (iNum <= MENU_REMOVE))
        {
            if (iNum == MENU_REQUEST && sToken == g_sParentMenu)
            {
             //   MenuResponse();
            }
        }      
        else if ((iNum >= COMMAND_OWNER) && (iNum <= COMMAND_WEARERLOCKEDOUT))
        {
            string sCommand;
            if (sToken == "settings")
            {
                Notify(kID,"prefix: " + g_sPrefix, FALSE);
                Notify(kID,"channel: " + (string)g_iListenChan, FALSE);
                string s=CollarVersion();
                if (s=="0.000") s="Version not correctly set";
                Notify(kID,"Collar Version: "+s,FALSE);
            }
            else if (sCMD == "ping")
            {
                llSay(GetOwnerChannel(kID,1111),(string)g_kWearer+":pong");
            }
            else if (sCMD == "objectversion")
              {
                llSay(GetOwnerChannel(kID,1111),(string)g_kWearer+":version="+CollarVersion());
            }
            else if (sCMD == "version")
            {
                string s=CollarVersion();
                if (s=="0.000") s="Version not correctly set";
                Notify(kID,"Collar Version: "+s,FALSE);
            }
            if (kID == g_kWearer)
            {
                if (sCommand == "safeword")
                {   // new for safeword
                    if(llStringTrim(sValue, STRING_TRIM) != "")
                    {
                       // g_sSafeWord = llList2String(lParams, 1);
                        llOwnerSay("You set a new safeword: " + g_sSafeWord + ".");
                        llMessageLinked(LINK_SET, SETTING_SAVE, "safeword=" + g_sSafeWord, NULL_KEY);
                    }
                    else
                    {
                        llOwnerSay("Your safeword is: " + g_sSafeWord + ".");
                    }
                }
                else if (sMsg == g_sSafeWord)
                { //safeword used with prefix
                    llMessageLinked(LINK_SET, COMMAND_SAFEWORD, "", NULL_KEY);
                    llOwnerSay("You used your safeword, your owner will be notified you did.");
                }
            }

            //handle changing prefix and channel from owner
            if (iNum == COMMAND_OWNER)
            {
                if (sCommand == "prefix")
                {
                  //  string sNewPrefix = llList2String(lParams, 1);
                //    if (sNewPrefix == "auto" || sNewPrefix == "")
                 //   {
                 //       g_sPrefix = AutoPrefix();
                 //   }
                  //  else 
                   // {
                   //     g_sPrefix = sNewPrefix;
                   // }
                    SetListeners();
                    Notify(kID, "\n" + llKey2Name(g_kWearer) + "'s prefix is '" + g_sPrefix + "'.\nTouch the collar or say '" + g_sPrefix + "menu' for the main menu.\nSay '" + g_sPrefix + "help' for a list of chat commands.", FALSE);
                    llMessageLinked(LINK_SET, SETTING_SAVE, "prefix=" + g_sPrefix, NULL_KEY);
                    llMessageLinked(LINK_SET, SETTING_REQUEST, "prefix", NULL_KEY);
                }
                else if (sCommand == "channel")
                {
             //       integer iNewChan = (integer)llList2String(lParams, 1);
        /*            if (iNewChan > 0)
                    {
                        g_iListenChan =  iNewChan;
                        SetListeners();
                        Notify(kID, "Now listening on channel " + (string)g_iListenChan + ".", FALSE);
                        if (g_iListenChan0)
                        {
                            llMessageLinked(LINK_SET, SETTING_SAVE, "channel=" + (string)g_iListenChan + ",TRUE", NULL_KEY);
                        }
                        else
                        {
                            llMessageLinked(LINK_SET, SETTING_SAVE, "channel=" + (string)g_iListenChan + ",FALSE", NULL_KEY);
                        }
                    }
                    else if (iNewChan == 0)
                    {
                        g_iListenChan0 = TRUE;
                        SetListeners();
                        Notify(kID, "You enabled the public channel listener.\nTo disable it use -1 as channel command.", FALSE);
                        llMessageLinked(LINK_SET, SETTING_SAVE, "channel=" + (string)g_iListenChan + ",TRUE", NULL_KEY);
                    }
                    else if (iNewChan == -1)
                    {
                        g_iListenChan0 = FALSE;
                        SetListeners();
                        Notify(kID, "You disabled the public channel listener.\nTo enable it use 0 as channel command, remember you have to do this on your channel /" +(string)g_iListenChan, FALSE);
                        llMessageLinked(LINK_SET, SETTING_SAVE, "channel=" + (string)g_iListenChan + ",FALSE", NULL_KEY);
                    }
                    else
                    {  //they left the param blank
                        Notify(kID, "Error: 'channel' must be given a number.", FALSE);
                    }
                    */
                }
            }

        }
        /*
        else if (iNum == POPUP_HELP)
        {
            //replace _PREFIX_ with prefix, and _CHANNEL_ with (strin) channel
            sStr = StringReplace(sStr, "_PREFIX_", g_sPrefix);
            sStr = StringReplace(sStr, "_CHANNEL_", (string)g_iListenChan);
            Notify(kID, sStr, FALSE);
        }
        //added for attachment auth (garvin)
        else if (iNum == ATTACHMENT_RESPONSE)
        {
            Debug(sStr);
            //here the response from auth has to be:
            // llMessageLinked(LINK_SET, ATTACHMENT_RESPONSE, "auth", UUID);
            //where "auth" has to be (string)COMMAND_XY
            //reason for this is: i dont want to have all other scripts recieve a COMMAND+xy and check further for the command
            llWhisper(g_iInterfaceChannel, "RequestReply|" + sStr + g_sSeparator + g_sCmd);
        } 
        */       
    }
    
    //no more self resets
    changed(integer iChange)
    {
        if (iChange & CHANGED_OWNER)
        {
            llResetScript();
        }
    }

    on_rez(integer iParam)
    {
        llResetScript();
    }
}