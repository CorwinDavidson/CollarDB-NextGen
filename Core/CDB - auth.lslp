/*--------------------------------------------------------------------------------**
**  File: CDB - auth                                                              **
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

//key owner;
//string g_lOwnerName;
list g_lOwners;     //strided list in form key,name
key g_kGroup = "";
string g_sGroupName;
integer g_iGroupEnabled = FALSE;
list g_lSecOwners;  //strided list in the form key,name
list g_lBlackList;  //list of blacklisted UUID
string g_sTmpName;  //used temporarily to store new owner or secowner name while retrieving key

string  g_sWikiURL = "http://www.collardb.com/static/UserDocumentation";
string g_sParentMenu = "Main";
string g_sSubMenu = "Owners";

string g_sRequestType; //may be "owner" or "secowner" or "remsecowner"
key g_kHTTPID;
key g_kGroupHTTPID;

string g_sOwnersToken = "owner";
string g_sSecOwnersToken = "secowners";
string g_sBlackListToken = "blacklist";

string g_sPrefix;

//dialog handlers
key g_kAuthMenuID;
key g_kSensorMenuID;

//added for attachment auth
integer g_iInterfaceChannel = -12587429;

string g_sSetOwner = "✚Primary Owner";
string g_sSetSecOwner = "✚Secondary Owner";
string g_sSetBlackList = "✚Blacklisted";
string g_sSetGroup = "Set Group";
string g_sReset = "Runaway!";
string g_sRemOwner = "✘Primary Owner";
string g_sRemSecOwner = "✘Secondary Owner";
string g_sRemBlackList = "✘Blacklisted";
string g_sUnsetGroup = "Unset Group";
string g_sListOwners = "List Owners";
string g_sSetOpenAccess = "SetOpenAccess";
string g_sUnsetOpenAccess = "UnsetOpenAccess";
string g_sSetLimitRange = "LimitRange";
string g_sUnsetLimitRange = "UnLimitRange";

//request types
string g_sOwnerScan = "ownerscan";
string g_sSecOwnerScan = "secownerscan";
string g_sBlackListScan = "blacklistscan";

integer g_iOpenAccess; // 0: disabled, 1: openaccess
integer g_iLimitRange=1; // 0: disabled, 1: limited
integer g_kWearerlocksOut;

integer g_iRemenu = FALSE;

key g_kDialoger;//the person using the dialog.  needed in the sensor event when scanning for new owners to add


$import lib.MessageMap.lslm ();
$import lib.CommonVariables.lslm ();
$import lib.CommonFunctions.lslm ();


integer POPUP_HELP              = -0xCDB001;      


integer RLV_CMD                 = 0xCDB600;
integer RLV_REFRESH             = 0xCDB601;     // RLV plugins should reinstate their restrictions upon receiving this message.
integer RLV_CLEAR               = 0xCDB602;     // RLV plugins should clear their restriction lists upon receiving this message.

integer ANIM_START              = 0xCDB700;     // send this with the name of an anim in the string part of the message to play the anim
integer ANIM_STOP               = 0xCDB701;     // send this with the name of an anim in the string part of the message to stop the anim

//this can change
integer WEARERLOCKOUT           = -0xCDB199;


NewPerson(key kID, string sName, string sType)
{//adds new owner, secowner, or blacklisted, as determined by type.
    if (sType == "owner")
    {
    	g_lOwners = SetCacheVal(g_lOwners,kID, sName,0);
        llMessageLinked(LINK_SET, SETTING_SAVE, g_sOwnersToken + "=" + llDumpList2String(g_lOwners, ","), "");
        //added for attachment interface to announce owners have changed
        llWhisper(g_iInterfaceChannel, "CollarCommand|499|OwnerChange");
    }
    else if (sType == "secowner")
    {
    	g_lSecOwners = SetCacheVal(g_lSecOwners,kID, sName,0);
        llMessageLinked(LINK_SET, SETTING_SAVE, g_sSecOwnersToken + "=" + llDumpList2String(g_lSecOwners, ","), "");
        //added for attachment interface to announce owners have changed
        llWhisper(g_iInterfaceChannel, "CollarCommand|499|OwnerChange");
    }
    else if (sType == "blacklist")
    {
    	g_lBlackList = SetCacheVal(g_lBlackList,kID, sName,0);
        llMessageLinked(LINK_SET, SETTING_SAVE, g_sBlackListToken + "=" + llDumpList2String(g_lBlackList, ","), "");
    }
    
    if (kID != g_kWearer)
    {
        Notify(g_kWearer, "Added " + sName + " to " + sType + ".", FALSE);
        if (sType == "owner")
        {
            Notify(g_kWearer, "Your owner can have a lot  power over you and you consent to that by making them your owner on your collar. They can leash you, put you in poses, lock your collar, see your location and what you say in local chat.  If you are using RLV they can  undress you, make you wear clothes, restrict your  chat, IMs and TPs as well as force TP you anywhere they like. Please read the help for more info. If you do not consent, you can use the command \"" + g_sPrefix + "runaway\" to remove all owners from the collar.", FALSE);
        }
    }

    if (sType == "owner" || sType == "secowner")
    { 
    	Notify(kID, "You have been added to the " + sType + " list on " + llKey2Name(g_kWearer) + "'s collar.\nFor help concerning the collar usage either say \"" + g_sPrefix + "help\" in chat or go to " + g_sWikiURL + " .",FALSE);
    }

}

Name2Key(string sFormattedName)
{   //formatted name is firstname+lastname
    g_kHTTPID = llHTTPRequest("http://w-hat.com/name2key?terse=1&name=" + sFormattedName, [HTTP_METHOD, "GET"], "");
}

AuthMenu(key kAv)
{
    string sPrompt = "Pick an option.";
    list lButtons = [g_sSetOwner, g_sSetSecOwner, g_sSetBlackList, g_sRemOwner, g_sRemSecOwner, g_sRemBlackList];

    if (g_kGroup=="") lButtons += [g_sSetGroup];    //set group
    else lButtons += [g_sUnsetGroup];    //unset group

    if (g_iOpenAccess) lButtons += [g_sUnsetOpenAccess];    //set open access
    else lButtons += [g_sSetOpenAccess];    //unset open access

    if (g_iLimitRange) lButtons += [g_sUnsetLimitRange];    //set ranged
    else lButtons += [g_sSetLimitRange];    //unset open ranged

    lButtons += [g_sReset];

    //list owners
    lButtons += [g_sListOwners];

    g_kAuthMenuID = Dialog(kAv, sPrompt, lButtons, [UPMENU], 0);
}

RemPersonMenu(key kID, list lPeople, string sType)
{
    g_sRequestType = sType;
    string sPrompt = "Choose the person to remove.";
    list lButtons;
    //build a button list with the dances, and "More"
    //get number of secowners
    integer iNum= llGetListLength(lPeople);
    integer n;
    for (n=1; n <= iNum/2; n = n + 1)
    {
        string sName = llList2String(lPeople, 2*n-1);
        if (sName != "")
        {
            sPrompt += "\n" + (string)(n) + " - " + sName;
            lButtons += [(string)(n)];
        }
    }
    lButtons += ["Remove All"];

    g_kSensorMenuID = Dialog(kID, sPrompt, lButtons, [UPMENU], 0);
}

integer in_range(key kID) {
    if (g_iLimitRange) {
        integer range = 20;
        vector kAvpos = llList2Vector(llGetObjectDetails(kID, [OBJECT_POS]), 0);
        if (llVecDist(llGetPos(), kAvpos) > range) {
            //llOwnerSay(llKey2Name(kID) + " is not in range...");
            llDialog(kID, "\n\nNot in range...", [], 298479);
            return FALSE;
        }
        else {
            //llOwnerSay(llKey2Name(kID) + " In range...");
            return TRUE;
        }
    }
    else {
        return TRUE;
    }
}

integer UserAuth(string kID, integer attachment)
{
    //Nan: the auth script in 3.3 had a separate UserAuthAttach function that was identical to this one except omitted
    //the lockout block (the first "if").  I've added the "attachment" argument to this function in 3.4 to accomplish the same thing
    //Let's try not to duplicate code if we don't have to!
    integer iNum;
    if (g_kWearerlocksOut && kID == (string)g_kWearer && !attachment)
    {
        iNum = COMMAND_WEARERLOCKEDOUT;
    }
    else if (~llListFindList(g_lOwners, [(string)kID]))
    {
        iNum = COMMAND_OWNER;
    }
    else if (llGetListLength(g_lOwners) == 0 && kID == (string)g_kWearer)
    {
        //if no owners set, then wearer's cmds have owner auth
        iNum = COMMAND_OWNER;
    }
    else if (~llListFindList(g_lBlackList, [(string)kID]))
    {
        iNum = COMMAND_BLACKLIST;
    }
    else if (~llListFindList(g_lSecOwners, [(string)kID]))
    {
        iNum = COMMAND_SECOWNER;
    }
    else if (kID == (string)g_kWearer)
    {
        iNum = COMMAND_WEARER;
    }
    else if (g_iOpenAccess)
    {
        if (in_range((key)kID))
            iNum = COMMAND_GROUP;
        else
            iNum = COMMAND_EVERYONE;
    }
    else if (llSameGroup(kID) && g_iGroupEnabled && kID != (string)g_kWearer)
    {
        if (in_range((key)kID))
            iNum = COMMAND_GROUP;
        else
            iNum = COMMAND_EVERYONE;
    }
    else
    {
        iNum = COMMAND_EVERYONE;
    }
    return iNum;
}

integer ObjectAuth(key obj, key kObjOwnerKey)
{
    integer iNum;
    if (g_kWearerlocksOut && kObjOwnerKey == g_kWearer)
    {
        iNum = COMMAND_WEARERLOCKEDOUT;
    }
    else if (~llListFindList(g_lOwners, [(string)kObjOwnerKey]))
    {
        iNum = COMMAND_OWNER;
    }
    else if (llGetListLength(g_lOwners) == 0 && kObjOwnerKey == g_kWearer)
    {
        //if no owners set, then wearer's objects' cmds have owner auth
        iNum = COMMAND_OWNER;
    }
    else if (~llListFindList(g_lBlackList, [(string)kObjOwnerKey]))
    {
        iNum = COMMAND_BLACKLIST;
    }
    else if (~llListFindList(g_lSecOwners, [(string)kObjOwnerKey]))
    {
        iNum = COMMAND_SECOWNER;
    }
    else if ((string)llGetObjectDetails(obj, [OBJECT_GROUP]) == (string)g_kGroup && kObjOwnerKey != g_kWearer)
    {//meaning that the command came from an object set to our control group, and is not owned by the wearer
        iNum = COMMAND_GROUP;
    }
    else if (g_iOpenAccess && llListFindList(g_lBlackList,[kObjOwnerKey])==-1)
    {
        iNum = COMMAND_GROUP;
    }
    else if (kObjOwnerKey == g_kWearer)
    {
        iNum = COMMAND_WEARER;
    }
    else
    {
        iNum = COMMAND_EVERYONE;
    }
    return iNum;
}

list RemovePerson(list lPeople, string sName, string sToken, key kCmdr)
{
    //where "lPeople" is a 2-strided list in form key,name
    //looks for strides identified by "name", removes them if found, and returns the list
    //also handles notifications so as to reduce code duplication in the link message event
//#mdebug info
//@    Debug("removing: " + sName);
//#enddebug    
    //all our comparisons will be cast to lower case first
    sName = llToLower(sName);
    integer iChange = FALSE;
    integer n;
    key kRemovedPerson;
    //loop from the top and work down, so we don't skip when we remove things
    for (n = llGetListLength(lPeople) - 1; n >= 0; n = n - 2)
    {
        string sThisName = llToLower(llList2String(lPeople, n));
//#mdebug info        
//@        Debug("checking " + sThisName);
//#enddebug       
        if (sName == sThisName)
        {   //remove name and key
            kRemovedPerson=llList2String(lPeople,n - 1);
            lPeople = llDeleteSubList(lPeople, n - 1, n);
            iChange = TRUE;
        }
    }

    if (iChange)
    {
        if (sToken == g_sOwnersToken || sToken == g_sSecOwnersToken)
        {// is it about owners?
            if (kRemovedPerson!=g_kWearer)
                // if it isnt the wearer, we are nice and notify them
            {
                if (sToken == g_sOwnersToken)
                {
                    Notify(kRemovedPerson,"You have been removed as owner on the collar of " + llKey2Name(g_kWearer) + ".",FALSE);
                }
                else
                {
                    Notify(kRemovedPerson,"You have been removed as secowner on the collar of " + llKey2Name(g_kWearer) + ".",FALSE);
                }
            }
            //whisper to attachments about owner and secowner changes
            llWhisper(g_iInterfaceChannel, "CollarCommand|499|OwnerChange");
        }
        //save to db
        if (llGetListLength(lPeople)>0)
        {
            llMessageLinked(LINK_SET, SETTING_SAVE, sToken + "=" + llDumpList2String(lPeople, ","), "");
        }
        else
        {
            llMessageLinked(LINK_SET, SETTING_DELETE, sToken, "");
        }
        Notify(kCmdr, sName + " removed from list.", TRUE);
    }
    else
    {
        Notify(kCmdr, "Error: '" + sName + "' not in list.",FALSE);
    }
    return lPeople;
}

integer isKey(string sIn) {
    if ((key)sIn) return TRUE;
    return FALSE;
}

integer OwnerCheck(key kID)
{//checks whether id has owner auth.  returns TRUE if so, else notifies person that they don't have that power
    //used in menu processing for when a non owner clicks an owner-only button
    if (UserAuth(kID, FALSE) == COMMAND_OWNER)
    {
        return TRUE;
    }
    else
    {
        Notify(kID, "Sorry, only an owner can do that.", FALSE);
        return FALSE;
    }
}

NotifyInList(list lStrideList, string sOwnerType)
{
    integer i;
    integer l=llGetListLength(lStrideList);
    key k;
    string sSubName = llKey2Name(g_kWearer);
    for (i = 0; i < l; i = i +2)
    {
        k = (key)llList2String(lStrideList,i);
        if (k != g_kWearer)
        {
            Notify(k,"You have been removed as " + sOwnerType + " on the collar of " + sSubName + ".",FALSE);
        }
    }
}

remenu(key kID)
{
    if (g_iRemenu) 
    {
        g_iRemenu=FALSE; 
        AuthMenu(kID);
    }
}



/*---------------//
//  MAIN CODE    //
//---------------*/
default
{
    state_entry()
    {   //until set otherwise, wearer is owner
    	g_lCacheTemplate =[""];
//#mdebug info    	
//@        Debug((string)llGetFreeMemory());
//#enddebug        
        g_kWearer = llGetOwner();
        list sName = llParseString2List(llKey2Name(g_kWearer), [" "], []);
        g_sPrefix = llToLower(llGetSubString(llList2String(sName, 0), 0, 0)) + llToLower(llGetSubString(llList2String(sName, 1), 0, 0));
        //added for attachment auth
        g_iInterfaceChannel = (integer)("0x" + llGetSubString(g_kWearer,30,-1));
        if (g_iInterfaceChannel > 0) g_iInterfaceChannel = -g_iInterfaceChannel;
        llMessageLinked(LINK_SET, SETTING_REQUEST, "prefix", NULL_KEY);
    }

    link_message(integer iSender, integer iNum, string sStr, key kID)
    {
        if ((iNum >= SETTING_SAVE) && (iNum <= SETTING_EMPTY))
        {
		    if (iNum == SETTING_RESPONSE)
		    {
		        list lParams = llParseString2List(sStr, ["="], []);
		        string sToken = llList2String(lParams, 0);
		        string sValue = llList2String(lParams, 1);
		        if (sToken == g_sOwnersToken)
		        {
		            g_lOwners = llParseString2List(sValue, [","], []);
		        }
		        else if (sToken == "group")
		        {
		            g_kGroup = (key)sValue;
		            //check to see if the object's group is set properly
		            if (g_kGroup != "")
		            {
		                if ((key)llList2String(llGetObjectDetails(llGetKey(), [OBJECT_GROUP]), 0) == g_kGroup)
		                {
		                    g_iGroupEnabled = TRUE;
		                }
		                else
		                {
		                    g_iGroupEnabled = FALSE;
		                }
		            }
		            else
		            {
		                g_iGroupEnabled = FALSE;
		            }
		        }
		        else if (sToken == "groupname")
		        {
		            g_sGroupName = sValue;
		        }
		        else if (sToken == "openaccess")
		        {
		            g_iOpenAccess = (integer)sValue;
		        }
		        else if (sToken == "limitrange")
		        {
		            g_iLimitRange = (integer)sValue;
		        }
		        else if (sToken == "secowners")
		        {
		            g_lSecOwners = llParseString2List(sValue, [","], [""]);
		        }
		        else if (sToken == "blacklist")
		        {
		            g_lBlackList = llParseString2List(sValue, [","], [""]);
		        }
		        else if (sToken == "prefix")
		        {
		            g_sPrefix = sValue;
		        }
		    }
        }
        else if ((iNum >= MENU_REQUEST) && (iNum <= MENU_REMOVE))
        {
		    if (iNum == MENU_SUBMENU)
		    {
		        if (sStr == g_sSubMenu)
		        {
		           AuthMenu(kID);
		        }            
		    }
		    else if (iNum == MENU_REQUEST && sStr == g_sParentMenu)
		    {
		         llMessageLinked(LINK_SET, MENU_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, "");
		    }
        }
        else if ((iNum >= DIALOG_TIMEOUT) && (iNum <= DIALOG_REQUEST))
        {
		    if (iNum == DIALOG_RESPONSE)
		    {
		        if (llListFindList([g_kAuthMenuID, g_kSensorMenuID], [kID]) != -1)
		        {
		            list lMenuParams = llParseString2List(sStr, ["|"], []);
		            key kAv = (key)llList2String(lMenuParams, 0);
		            string sMessage = llList2String(lMenuParams, 1);
		            integer iPage = (integer)llList2String(lMenuParams, 2);
		            if (kID == g_kAuthMenuID)
		            {
		                //g_kAuthMenuID responds to setowner, setsecowner, setblacklist, remowner, remsecowner, remblacklist
		                //setgroup, unsetgroup, setopenaccess, unsetopenaccess
		                if (sMessage == UPMENU)
		                {
		                    llMessageLinked(LINK_SET, MENU_SUBMENU, g_sParentMenu, kAv);
		                }
		                if (OwnerCheck(kAv))
		                {
		                    if ((sMessage == g_sSetOwner) || (sMessage == g_sSetSecOwner) || (sMessage == g_sSetBlackList))
		                    {
		                        if (sMessage == g_sSetOwner)
		                        {
		                            g_sRequestType = g_sOwnerScan;
		                        }
		                        else if (sMessage == g_sSetSecOwner)
		                        {
		                            g_sRequestType = g_sSecOwnerScan;
		                        }
		                        else if (sMessage == g_sSetBlackList)
		                        {
		                            g_sRequestType = g_sBlackListScan;
		                        }
		
		                        g_kDialoger = kAv;
		                        llSensor("", "", AGENT, 10.0, PI);
		                    }
		                    else if (sMessage == g_sRemOwner)
		                    {
		                        RemPersonMenu(kAv, g_lOwners, "remowners");
		                    }
		                    else if (sMessage == g_sRemSecOwner)
		                    {   
		                        RemPersonMenu(kAv, g_lSecOwners, "remsecowner");
		                    }
		                    else if (sMessage == g_sRemBlackList)
		                    {   
		                        RemPersonMenu(kAv, g_lBlackList, "remblacklist");
		                    }
		                }
		                if (sMessage == g_sSetGroup)
		                {
		                    g_iRemenu = TRUE;
		                    llMessageLinked(LINK_SET, COMMAND_NOAUTH, "setgroup", kAv);
		                }
		                else if (sMessage == g_sUnsetGroup)
		                {
		                    g_iRemenu = TRUE;
		                    llMessageLinked(LINK_SET, COMMAND_NOAUTH, "unsetgroup", kAv);
		                }
		                else if (sMessage == g_sSetOpenAccess)
		                {
		                    g_iRemenu = TRUE;
		                    llMessageLinked(LINK_SET, COMMAND_NOAUTH, "setopenaccess", kAv);
		                }
		                else if (sMessage == g_sUnsetOpenAccess)
		                {
		                    g_iRemenu = TRUE;
		                    llMessageLinked(LINK_SET, COMMAND_NOAUTH, "unsetopenaccess", kAv);
		                }
		                else if (sMessage == g_sSetLimitRange)
		                {
		                    g_iRemenu = TRUE;
		                    llMessageLinked(LINK_SET, COMMAND_NOAUTH, "setlimitrange", kAv);
		                }
		                else if (sMessage == g_sUnsetLimitRange)
		                {
		                    g_iRemenu = TRUE;
		                    llMessageLinked(LINK_SET, COMMAND_NOAUTH, "unsetlimitrange", kAv);
		                }
		                else if (sMessage == g_sReset)
		                {
		                    llMessageLinked(LINK_SET, COMMAND_NOAUTH, "runaway", kAv);
		                }
		                else if (sMessage == g_sListOwners)
		                {
		//#mdebug info                	
		//@                    Debug("ListOwner:" + (string)kAv);
		//#enddebug                    
		                    llMessageLinked(LINK_SET, COMMAND_NOAUTH, "listowners", kAv);
		                    AuthMenu(kAv);
		                }
		            }
		            else if (kID == g_kSensorMenuID)
		            {
		                if (sMessage != UPMENU)
		                {
		//#mdebug info                	
		//@                    Debug(g_sRequestType);
		//#enddebug                    
		                    if (OwnerCheck(kAv))
		                    {
		                        if (sMessage == "Remove All")
		                        {
		                            //g_sRequestType should be g_sRemOwner, g_sRemSecOwner, or g_sRemBlackList
		                            llMessageLinked(LINK_SET, COMMAND_OWNER, g_sRequestType + " Remove All", kAv);
		                        }
		                        else if (llGetSubString(g_sRequestType,0,2) == "rem")
		                        {
		                            //build a chat command to send to remove the person
		                            string sCmd = g_sRequestType;
		                            //convert the menu button number to a name
		                            if (g_sRequestType == "remowners")
		                            {
		                                sCmd += " " + llList2String(g_lOwners, (integer)sMessage*2 - 1);
		                            }
		                            else if(g_sRequestType == "remsecowner")
		                            {
		                                sCmd += " " + llList2String(g_lSecOwners, (integer)sMessage*2 - 1);
		                            }
		                            else if(g_sRequestType == "remblacklist")
		                            {
		                                sCmd += " " + llList2String(g_lBlackList, (integer)sMessage*2 - 1);
		                            }
		                            llMessageLinked(LINK_SET, COMMAND_OWNER, sCmd, kAv);
		                        }
		                    }
		                    if(g_sRequestType == g_sOwnerScan)
		                    {
		                        llMessageLinked(LINK_SET, COMMAND_OWNER, "owner " + sMessage, kAv);
		                    }
		                    else if(g_sRequestType == g_sSecOwnerScan)
		                    {
		                        llMessageLinked(LINK_SET, COMMAND_OWNER, "secowner " + sMessage, kAv);
		                    }
		                    else if(g_sRequestType == g_sBlackListScan)
		                    {
		                        llMessageLinked(LINK_SET, COMMAND_OWNER, "blacklist " + sMessage, kAv);
		                    }
		                }
		                AuthMenu(kAv);
		            }
		        }
		    }
        }        
        else if ((iNum >= COMMAND_WEARERLOCKEDOUT) && (iNum <= COMMAND_OWNER))
        {
		   if (iNum >= COMMAND_WEARER && iNum <= COMMAND_OWNER)
		    {   //give owner menu
		        if (sStr == "owners")
		        {
		            AuthMenu(kID);
		            return;            
		        }
		    }
		    
		    if (iNum == COMMAND_OBJECT)
		    {   //on object sent a command, see if that object's owner is an owner or secowner in the collar
		        //or if the object is set to the same group, and group is enabled in the collar
		        //or if object is owned by wearer
		        key kObjOwnerKey = llGetOwnerKey(kID);
		        integer iAuth = ObjectAuth(kID, kObjOwnerKey);
		        llMessageLinked(LINK_SET, iAuth, sStr, kID);
		//#mdebug info        
		//@        Debug("noauth: " + sStr + " from object " + (string)kID + " who has auth " + (string)iAuth);
		//#enddebug        
		    }
		    
		    if (iNum == COMMAND_OWNER || kID == g_kWearer)
		    {
		//#mdebug info    	
		//@        Debug("COMMAND_OWNER: " + sStr);
		//#enddebug        
		        if (sStr == "settings" || sStr == "listowners")
		        {   //say owner, secowners, group
		            //Nan: This used to be in a function called SendOwnerSettings, but it was *only* called here, and
		            //that's a waste of
		            //Do Owners list
		            integer n;
		            integer iLength = llGetListLength(g_lOwners);
		            string sOwners;
		            for (n = 0; n < iLength; n = n + 2)
		            {
		                sOwners += "\n" + llList2String(g_lOwners, n + 1) + " (" + llList2String(g_lOwners, n) + ")";
		            }
		            Notify(kID, "Owners: " + sOwners,FALSE);
		
		            //Do Secowners list
		            iLength = llGetListLength(g_lSecOwners);
		            string sSecOwners;
		            for (n = 0; n < iLength; n = n + 2)
		            {
		                sSecOwners += "\n" + llList2String(g_lSecOwners, n + 1) + " (" + llList2String(g_lSecOwners, n) + ")";
		            }
		            Notify(kID, "Secowners: " + sSecOwners,FALSE);
		            iLength = llGetListLength(g_lBlackList);
		            string sBlackList;
		            for (n = 0; n < iLength; n = n + 2)
		            {
		                sBlackList += "\n" + llList2String(g_lBlackList, n + 1) + " (" + llList2String(g_lBlackList, n) + ")";
		            }
		            Notify(kID, "Black List: " + sBlackList,FALSE);
		            Notify(kID, "Group: " + g_sGroupName,FALSE);
		            Notify(kID, "Group Key: " + (string)g_kGroup,FALSE);
		            string sVal; if (g_iOpenAccess) sVal="true"; else sVal="false";
		            Notify(kID, "Open Access: "+ sVal,FALSE);
		            string sValr; if (g_iLimitRange) sValr="true"; else sValr="false";
		            Notify(kID, "LimitRange: "+ sValr,FALSE);
		        }
		        else if (sStr == "runaway" || sStr == "reset")
		        {
		            // alllow only for the wearer
		            if (iNum == COMMAND_OWNER || kID == g_kWearer)
		            {    //IM Owners
		                Notify(g_kWearer, "Running away from all owners started, your owners will now be notified!",FALSE);
		                integer n;
		                integer stop = llGetListLength(g_lOwners);
		                for (n = 0; n < stop; n += 2)
		                {
		                    key kOwner = (key)llList2String(g_lOwners, n);
		                    if (kOwner != g_kWearer)
		                    {
		                        Notify(kOwner, llKey2Name(g_kWearer) + " has run away!",FALSE);
		                    }
		                }
		                Notify(g_kWearer, "Runaway finished, the collar will now reset!",FALSE);
		                // moved reset request from settings to here to allow noticifation of owners.
		                llMessageLinked(LINK_SET, COMMAND_OWNER, "clear", kID);
		                llMessageLinked(LINK_SET, COMMAND_OWNER, "resetscripts", kID);
		                llResetScript();
		            }
		        }
		        
		    }
		    
		    if (iNum == COMMAND_OWNER)
		    { //respond to messages to set or unset owner, group, or secowners.  only owner may do these things
		        list lParams = llParseString2List(sStr, [" "], []);
		        string sCommand = llList2String(lParams, 0);
		        if (sCommand == "owner")
		        { //set a new owner.  use w-hat sName2key service.  benefits: not case sensitive, and owner need not be present
		            //if no owner at all specified:
		            if (llList2String(lParams, 1) == "")
		            {
		                AuthMenu(kID);
		                return;
		            }
		            g_sRequestType = "owner";
		            //pop the command off the param list, leaving only first and last name
		            lParams = llDeleteSubList(lParams, 0, 0);
		            //record owner name
		            if (llGetListLength(lParams) == 1) lParams += ["Resident"];
		            g_sTmpName = llDumpList2String(lParams, " ");
		            //sensor for the owner name to get the key or set the owner directly if it is the wearer
		            if(llToLower(g_sTmpName) == llToLower(llKey2Name(g_kWearer)))
		            {
		                NewPerson(g_kWearer, g_sTmpName, "owner");
		            }
		            else
		            {
		                g_kDialoger = kID;
		                llSensor("","", AGENT, 20.0, PI);
		            }
		        }
		        else if (sCommand == "remowners")
		        { //remove secowner, if in the list
		            g_sRequestType = "";//Nan: this used to be set to "remowners" but that NEVER gets filtered on elsewhere in the script.  Just clearing it now in case later filtering relies on it being cleared.  I hate this g_sRequestType variable with a passion
		            //pop the command off the param list, leaving only first and last name
		            lParams = llDeleteSubList(lParams, 0, 0);
		            //name of person concerned
		            if (llGetListLength(lParams) == 1) lParams += ["Resident"];
		            g_sTmpName = llDumpList2String(lParams, " ");
		            if (g_sTmpName=="")
		            {
		                RemPersonMenu(kID, g_lOwners, "remowners");
		            }
		            else if(llToLower(g_sTmpName) == "remove all")
		            {
		                Notify(kID, "Removing of all owners started!",TRUE);
		
		                NotifyInList(g_lOwners, g_sOwnersToken);
		
		                g_lOwners = [];
		                llMessageLinked(LINK_SET, SETTING_DELETE, g_sOwnersToken, "");
		                Notify(kID, "Everybody was removed from the owner list!",TRUE);
		            }
		            else
		            {
		                g_lOwners = RemovePerson(g_lOwners, g_sTmpName, g_sOwnersToken, kID);
		            }
		        }
		        else if (sCommand == "secowner")
		        { //set a new secowner
		            g_sRequestType = "secowner";
		            //pop the command off the param list, leaving only first and last name
		            lParams = llDeleteSubList(lParams, 0, 0);
		            //record owner name
		            if (llGetListLength(lParams) == 1) lParams += ["Resident"];
		            g_sTmpName = llDumpList2String(lParams, " ");
		            if (g_sTmpName=="")
		            {
		                g_sRequestType = g_sSecOwnerScan;
		                g_kDialoger = kID;
		                llSensor("", "", AGENT, 10.0, PI);
		            }
		            else if (llGetListLength(g_lSecOwners) == 20)
		            {
		                Notify(kID, "The maximum of 10 secowners is reached, please clean up or use SetGroup",FALSE);
		            }
		            else
		            {//sensor for the owner name to get the key or set the owner directly if it is the wearer
		                if(llToLower(g_sTmpName) == llToLower(llKey2Name(g_kWearer)))
		                {
		                    NewPerson(g_kWearer, g_sTmpName, "secowner");
		                }
		                else
		                {
		                    g_kDialoger = kID;
		                    llSensor("","", AGENT, 20.0, PI);
		                }
		            }
		        }
		        else if (sCommand == "remsecowner")
		        { //remove secowner, if in the list
		            g_sRequestType = "";
		            //pop the command off the param list, leaving only first and last name
		            lParams = llDeleteSubList(lParams, 0, 0);
		            //name of person concerned
		            if (llGetListLength(lParams) == 1) lParams += ["Resident"];
		            g_sTmpName = llDumpList2String(lParams, " ");
		            if (g_sTmpName=="")
		            {
		                RemPersonMenu(kID, g_lSecOwners, "remsecowner");
		            }
		            else if(llToLower(g_sTmpName) == "remove all")
		            {
		                Notify(kID, "Removing of all secowners started!",TRUE);
		
		                NotifyInList(g_lSecOwners, g_sSecOwnersToken);
		
		                g_lSecOwners = [];
		                llMessageLinked(LINK_SET, SETTING_DELETE, "secowners", "");
		                Notify(kID, "Everybody was removed from the secondary owner list!",TRUE);
		            }
		            else
		            {
		                g_lSecOwners = RemovePerson(g_lSecOwners, g_sTmpName, g_sSecOwnersToken, kID);
		            }
		        }
		        else if (sCommand == "blacklist")
		        { //blackList an avatar
		            g_sRequestType = "blacklist";
		            //pop the command off the param list, leaving only first and last name
		            lParams = llDeleteSubList(lParams, 0, 0);
		            //record blacklisted name
		            if (llGetListLength(lParams) == 1) lParams += ["Resident"];
		            g_sTmpName = llDumpList2String(lParams, " ");
		            if (g_sTmpName=="")
		            {
		                g_sRequestType = g_sBlackListScan;
		                g_kDialoger = kID;
		                llSensor("", "", AGENT, 10.0, PI);
		            }
		            else if (llGetListLength(g_lBlackList) == 20)
		            {
		                Notify(kID, "The maximum of 10 blacklisted is reached, please clean up.",FALSE);
		            }
		            else
		            {   //sensor for the blacklisted name to get the key
		                g_kDialoger = kID;
		                llSensor("","", AGENT, 20.0, PI);
		            }
		        }
		        else if (sCommand == "remblacklist")
		        { //remove blacklisted, if in the list
		            g_sRequestType = "";
		            //g_sRequestType = "remblacklist";//Nan: we never filter on g_sRequestType == "remblacklist", so this makes no sense.
		            //pop the command off the param list, leaving only first and last name
		            lParams = llDeleteSubList(lParams, 0, 0);
		            //name of person concerned
		            if (llGetListLength(lParams) == 1) lParams += ["Resident"];
		            g_sTmpName = llDumpList2String(lParams, " ");
		            if (g_sTmpName=="")
		            {
		                RemPersonMenu(kID, g_lBlackList, "remblacklist");
		            }
		            else if(llToLower(g_sTmpName) == "remove all")
		            {
		                g_lBlackList = [];
		                llMessageLinked(LINK_SET, SETTING_DELETE, g_sBlackListToken, "");
		                Notify(kID, "Everybody was removed from black list!", TRUE);
		            }
		            else
		            {
		                g_lBlackList = RemovePerson(g_lBlackList, g_sTmpName, g_sBlackListToken, kID);
		            }
		        }
		        else if (sCommand == "setgroup")
		        {
		            g_sRequestType = "group";
		            //if no arguments given, use current group, else use key provided
		            if (isKey(llList2String(lParams, 1)))
		            {
		                g_kGroup = (key)llList2String(lParams, 1);
		            }
		            else
		            {
		                //record current group key
		                g_kGroup = (key)llList2String(llGetObjectDetails(llGetKey(), [OBJECT_GROUP]), 0);
		            }
		
		            if (g_kGroup != "")
		            {
		                llMessageLinked(LINK_SET, SETTING_SAVE, "group=" + (string)g_kGroup, "");
		                g_iGroupEnabled = TRUE;
		                g_kDialoger = kID;
		                //get group name from
		                g_kGroupHTTPID = llHTTPRequest("http://data.collardb.com/groupname/GetGroupName?group=" + (string)g_kGroup, [HTTP_METHOD, "GET"], "");
		            }
		            remenu(kID);
		        }
		        else if (sCommand == "setgroupname")
		        {
		            g_sGroupName = llDumpList2String(llList2List(lParams, 1, -1), " ");
		            llMessageLinked(LINK_SET, SETTING_SAVE, "groupname=" + g_sGroupName, "");
		        }
		        else if (sCommand == "unsetgroup")
		        {
		            g_kGroup = "";
		            g_sGroupName = "";
		            llMessageLinked(LINK_SET, SETTING_DELETE, "group", "");
		            llMessageLinked(LINK_SET, SETTING_DELETE, "groupname", "");
		            g_iGroupEnabled = FALSE;
		            Notify(kID, "Group unset.", FALSE);
		            remenu(kID);
		            //added for attachment interface to announce owners have changed
		            llWhisper(g_iInterfaceChannel, "CollarCommand|499|OwnerChange");
		        }
		        else if (sCommand == "setopenaccess")
		        {
		            g_iOpenAccess = TRUE;
		            llMessageLinked(LINK_SET, SETTING_SAVE, "openaccess=" + (string) g_iOpenAccess, "");
		            Notify(kID, "Open access set.", FALSE);
		            remenu(kID);
		        }
		        else if (sCommand == "unsetopenaccess")
		        {
		            g_iOpenAccess = FALSE;
		            llMessageLinked(LINK_SET, SETTING_DELETE, "openaccess", "");
		            Notify(kID, "Open access unset.", FALSE);
		            remenu(kID);
		            //added for attachment interface to announce owners have changed
		            llWhisper(g_iInterfaceChannel, "CollarCommand|499|OwnerChange");
		        }
		        else if (sCommand == "setlimitrange")
		        {
		            g_iLimitRange = TRUE;
		            // as the default is range limit on, we do not need to store anything for this
		            llMessageLinked(LINK_SET, SETTING_DELETE, "limitrange", "");
		            Notify(kID, "Range limited set.", FALSE);
		            remenu(kID);
		        }
		        else if (sCommand == "unsetlimitrange")
		        {
		            g_iLimitRange = FALSE;
		            // save off state for limited range (default is on)
		            llMessageLinked(LINK_SET, SETTING_SAVE, "limitrange=" + (string) g_iLimitRange, "");
		            Notify(kID, "Range limited unset.", FALSE);
		            remenu(kID);
		        }
		        else if (sCommand == "reset")
		        {
		            llResetScript();
		        }
		    }
		    else if (iNum == COMMAND_SAFEWORD)
		    {
		        string sSubName = llKey2Name(g_kWearer);
		        string sSubFirstName = llList2String(llParseString2List(sSubName, [" "], []), 0);
		        integer n;
		        integer iStop = llGetListLength(g_lOwners);
		        for (n = 0; n < iStop; n += 2)
		        {
		            key kOwner = (key)llList2String(g_lOwners, n);
		            Notify(kOwner, "Your sub " + sSubName + " has used the safeword. Please check on " + sSubFirstName +"'s well-being and if further care is required.",FALSE);
		        }
		        //added for attachment interface (Garvin)
		        llWhisper(g_iInterfaceChannel, "CollarCommand|499|safeword");
		    }    

        }
        else if (iNum == COMMAND_NOAUTH)
        {
            integer iAuth = UserAuth((string)kID, FALSE);

            if ((sStr=="reset") && (iAuth>=COMMAND_OWNER) && (iAuth<=COMMAND_WEARER))
            {
                Notify(kID, "The command 'reset' is deprecated. Please use 'runaway' to leave the owner and clear all settings or 'resetscripts' to only reset the script in the collar.", FALSE);
            }
            else
            {
                llMessageLinked(LINK_SET, iAuth, sStr, kID);
            }
//#mdebug info
//@            Debug("noauth: " + sStr + " from " + (string)kID + " who has auth " + (string)iAuth);
//#enddebug            
        }
        //added for attachment auth (Garvin)
//        else if (iNum == ATTACHMENT_REQUEST)
//        {
//            integer iAuth = UserAuth((string)kID, TRUE);
//            llMessageLinked(LINK_SET, ATTACHMENT_RESPONSE, (string)iAuth, kID);
//        }
        else if (iNum == WEARERLOCKOUT)
        {
            if (sStr == "on")
            {
                g_kWearerlocksOut=TRUE;
//#mdebug info                
//@                Debug("locksOuton");
//#enddebug                
            }
            else if (sStr == "off")
            {
                g_kWearerlocksOut=FALSE;
//#mdebug info                
//@                Debug("lockoutoff");
//#enddebug                
            }
        }
        
    }
    
    sensor(integer iNum_detected)
    {
        if(g_sRequestType == "owner" || g_sRequestType == "secowner" || g_sRequestType == "blacklist")
        {
            integer i;
            integer iFoundAvi = FALSE;
            for (i = 0; i < iNum_detected; i++)
            {//see if sensor picked up person with name we were given in chat command (g_sTmpName).  case insensitive
                if(llToLower(g_sTmpName) == llToLower(llDetectedName(i)))
                {
                    iFoundAvi = TRUE;
                    NewPerson(llDetectedKey(i), llDetectedName(i), g_sRequestType);
                    i = iNum_detected;//a clever way to jump out of the loop.  perhaps too clever?
                }
            }
            if(!iFoundAvi)
            {
                if(g_sTmpName == llKey2Name(g_kWearer))
                {
                    NewPerson(g_kWearer, llKey2Name(g_kWearer), g_sRequestType);
                }
                else
                {
                    list lTemp = llParseString2List(g_sTmpName, [" "], []);
                    Name2Key(llDumpList2String(lTemp, "+"));
                }
            }
        }
        else if(g_sRequestType == g_sOwnerScan || g_sRequestType == g_sSecOwnerScan || g_sRequestType == g_sBlackListScan)
        {
            list lButtons;
            string sName;
            integer i;

            for(i = 0; i < iNum_detected; i++)
            {
                sName = llDetectedName(i);
                
                lButtons += [sName];
            }
            //add wearer if not already in button list
            sName = llKey2Name(g_kWearer);
            if (llListFindList(lButtons, [sName]) == -1)
            {
                lButtons = [sName] + lButtons;
            }
            if (llGetListLength(lButtons) > 0)
            {
                string sText = "Select who you would like to add.\nIf the one you want to add does not show, move closer and repeat or use the chat command.";
                g_kSensorMenuID = Dialog(g_kDialoger, sText, lButtons, [UPMENU], 0);
            }
        }
    }

    no_sensor()
    {
        if(g_sRequestType == "owner" || g_sRequestType == "secowner" || g_sRequestType == "blacklist")
        {
            //reformat name with + in place of spaces
            Name2Key(llDumpList2String(llParseString2List(g_sTmpName, [" "], []), "+"));
        }
        else if(g_sRequestType == g_sOwnerScan || g_sRequestType == g_sSecOwnerScan || g_sRequestType == g_sBlackListScan)
        {
            string sText = "No one is in the 10m range to be shown.  You may add yourself or move closer to the person you want to add and try again, or use the chat command to add someone who is not with you at this moment or offline.";
            g_kSensorMenuID = Dialog(g_kDialoger, sText, [llKey2Name(g_kWearer)], [UPMENU], 0);
        }
    }

    on_rez(integer iParam)
    {
        llResetScript();
    }

    changed(integer iChange)
    {
        if (iChange & CHANGED_OWNER)
        {
            g_kWearer = llGetOwner();
        }
    }

    http_response(key kID, integer iStatus, list lMeta, string sBody)
    {
        if (kID == g_kHTTPID)
        {   //here's where we add owners or secowners, after getting their keys
            if (iStatus == 200)
            {
//#mdebug info            	
//@                Debug(sBody);
//#enddebug                
                if (isKey(sBody))
                {
                    NewPerson((key)sBody, g_sTmpName, g_sRequestType);//g_sRequestType will be owner, secowner, or blacklist
                }
                else
                {
                    Notify(g_kDialoger, "Error: unable to retrieve key for '" + g_sTmpName + "'.", FALSE);
                }
            }
        }
        else if (kID == g_kGroupHTTPID)
        {
            if (iStatus == 200)
            {
                if (sBody == "X")
                {
                    Notify(g_kDialoger, "Group set to (group name hidden).", FALSE);
                }
                else if (llStringLength(sBody)>36)
                {
                    Notify(g_kDialoger, "Error retrieving group name! Group set to (group name hidden)", TRUE);
                    sBody="X";
                }
                else
                {
                    Notify(g_kDialoger, "Group set to " + sBody, FALSE);
                }
                g_sGroupName = sBody;
                llMessageLinked(LINK_SET, SETTING_SAVE, "groupname=" + g_sGroupName, "");
            }
        }
    }
}
