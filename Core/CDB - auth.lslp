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

$import lib.MessageMap.lslm ();
$import lib.CommonVariables.lslm ();
$import lib.CommonFunctions.lslm ();

/*-------------//
//  VARIABLES  //
//-------------*/

//key owner;
//string g_lOwnerName;

string g_sGroupName;

string g_sTmpName;  //used temporarily to store new owner or secowner name while retrieving key

string  WIKIURL = "http://www.collardb.com/static/UserDocumentation";

string g_sParentMenu = "Main";
string g_sSubMenu = "Owners";

string g_sRequestType; //may be "owner" or "secowner" or "remsecowner"

key g_kHTTPID;
key g_kGroupHTTPID;

list g_lAuthTokens = ["","owner","secowner","blacklist"];
list g_lRemAuthTokens = ["","remowners","remsecowner","remblacklist"];

string g_sPrefix;

//dialog handlers
key g_kAuthMenuID;
key g_kSensorMenuID;

//added for attachment auth
integer g_iInterfaceChannel = -12587429;

string g_sSetOwner = "?Primary Owner";
string g_sSetSecOwner = "?Secondary Owner";
string g_sSetBlackList = "?Blacklisted";
string g_sSetGroup = "Group ?";
string g_sRunaway = "Runaway!";
string g_sRemOwner = "?Primary Owner";
string g_sRemSecOwner = "?Secondary Owner";
string g_sRemBlackList = "?Blacklisted";
string g_sUnsetGroup = "Group ?";
string g_sListOwners = "List Owners";
string g_sSetOpenAccess = "Public ?";
string g_sUnsetOpenAccess = "Public ?";
string g_sSetLimitRange = "LimitRange ?";
string g_sUnsetLimitRange = "LimitRange ?";

//request types
string g_sOwnerScan = "ownerscan";
string g_sSecOwnerScan = "secownerscan";
string g_sBlackListScan = "blacklistscan";

integer g_iLimitRange=1; // 0: disabled, 1: limited

integer g_iRemenu = FALSE;

key g_kDialoger;//the person using the dialog.  needed in the sensor event when scanning for new owners to add

/*-------------//
//  FUNCTIONS  //
//-------------*/

NewPerson(key kID, string sName, string sType)
{//adds new owner, secowner, or blacklisted, as determined by type.
    if (~llListFindList(g_lAuthTokens,[sType]))
    {
	    setAuthList(llListFindList(g_lAuthTokens,[sType]),SetCacheVal(getAuthList(llListFindList(g_lAuthTokens,[sType]),FALSE),kID, sName,0));
	    llMessageLinked(LINK_SET, SETTING_SAVE, sType + "=" + llDumpList2String(getAuthList(OWNERLIST,FALSE), ","), "");		
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
    	Notify(kID, "You have been added to the " + sType + " list on " + llKey2Name(g_kWearer) + "'s collar.\nFor help concerning the collar usage either say \"" + g_sPrefix + "help\" in chat or go to " + WIKIURL + " .",FALSE);
    }
}

RemovePerson(string sName, string sToken, key kCmdr)
{
//#mdebug info
    Debug("removing: " + sName);
//#enddebug

    integer iAuthIndex = llListFindList(g_lRemAuthTokens,[sToken]);
    if (~iAuthIndex)
    {
    	string sAuthToken = llList2String(g_lAuthTokens,iAuthIndex);
	    //all our comparisons will be cast to lower case first
	    sName = llToLower(sName);
	    
	    integer iIndex = llListFindList(getAuthList(iAuthIndex,TRUE),[sName]);
	    
	    if(iIndex != -1)
	    {
	    	list lTemp = getAuthList(iAuthIndex,FALSE);
	    	key kRemovedPerson = llList2String(lTemp,iIndex -1);
	    	string sThisName = llList2String(lTemp,iIndex);
	    	lTemp = llDeleteSubList(lTemp, iIndex -1 , iIndex);
	    	setAuthList(iAuthIndex,lTemp);

	        if (iAuthIndex >=1 || iAuthIndex <= 2)
	        {
	        	if (kRemovedPerson!=g_kWearer)
	            {
	            	Notify(kRemovedPerson,"You have been removed as " + sAuthToken + " on the collar of " + llKey2Name(g_kWearer) + ".",FALSE);
	            }
	        }
	        
	        
	        if (llGetListLength(lTemp)>0)
	        {
	            llMessageLinked(LINK_SET, SETTING_SAVE, sAuthToken + "=" + llDumpList2String(lTemp, ","), "");
	        }
	        else
	        {
	            llMessageLinked(LINK_SET, SETTING_DELETE, sAuthToken, "");
	        }
	        
	        Notify(kCmdr, sName + " removed from list.", TRUE);	              
	    }
	    else
	    {
	        Notify(kCmdr, "Error: '" + sName + "' not in list.",FALSE);
	    }		    
    }
}

Name2Key(string sFormattedName)
{   //formatted name is firstname+lastname
    g_kHTTPID = llHTTPRequest("http://w-hat.com/name2key?terse=1&name=" + sFormattedName, [HTTP_METHOD, "GET"], "");
    //g_kHTTPID = llHTTPRequest("http://name2key.haxworx.net/?terse=1&name=" + sFormattedName, [HTTP_METHOD, "GET"], "");

}

AuthMenu(key kAv)
{
    string sPrompt = "Pick an option.";
    list lButtons = [g_sSetOwner, g_sSetSecOwner, g_sSetBlackList, g_sRemOwner, g_sRemSecOwner, g_sRemBlackList];
    key kGroup = (string)llGetLinkMedia(LINK_THIS,0,[PRIM_MEDIA_WHITELIST]);
    integer iOpenAccess = (integer)((string)llGetLinkMedia(LINK_THIS,0,[PRIM_MEDIA_AUTO_SCALE]));

    if (kGroup=="") lButtons += [g_sSetGroup];    //set group
    else lButtons += [g_sUnsetGroup];    //unset group

    if (iOpenAccess) lButtons += [g_sUnsetOpenAccess];    //set open access
    else lButtons += [g_sSetOpenAccess];    //unset open access

    if (g_iLimitRange) lButtons += [g_sUnsetLimitRange];    //set ranged
    else lButtons += [g_sSetLimitRange];    //unset open ranged

    lButtons += [g_sRunaway];

    //list owners
    lButtons += [g_sListOwners];

    g_kAuthMenuID = Dialog(kAv, sPrompt, lButtons, [UPMENU], 0);
}

RemPersonMenu(key kID, string sType)
{
    g_sRequestType = sType;
    string sPrompt = "Choose the person to remove.";
    list lButtons;
    list lPeople = getAuthList(llListFindList(g_lRemAuthTokens,[sType]),FALSE);
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

integer isKey(string sIn) {
    if ((key)sIn) return TRUE;
    return FALSE;
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

//pragma inline
userCommand(string sCmd, list lParams, key kAv, integer iIsChat)
{
	if ((sCmd == g_sSetGroup) || (sCmd == "setgroup"))
	{
	    g_sRequestType = "group";
	    //if no arguments given, use current group, else use key provided
	    if(iIsChat)
	    {
		    if (isKey(llList2String(lParams, 1)))
		    {
		        llSetLinkMedia(LINK_THIS,0,[PRIM_MEDIA_WHITELIST,llList2String(lParams, 1)]);
		    }
	    }
	    else
	    {
	        //record current group key
	        llSetLinkMedia(LINK_THIS,0,[PRIM_MEDIA_WHITELIST,llList2String(llGetObjectDetails(llGetKey(), [OBJECT_GROUP]), 0)]);
	    }
		
	    if ((string)llGetLinkMedia(LINK_THIS,0,[PRIM_MEDIA_WHITELIST]) != "")
	    {
	        llMessageLinked(LINK_SET, SETTING_SAVE, "group=" + (string)llGetLinkMedia(LINK_THIS,0,[PRIM_MEDIA_WHITELIST]), "");
	        llGetLinkMedia(LINK_THIS,0,[PRIM_MEDIA_AUTO_ZOOM,TRUE]);
	        g_kDialoger = kAv;
	        //get group name from
	        g_kGroupHTTPID = llHTTPRequest("http://data.collardb.com/groupname/GetGroupName?group=" + (string)llGetLinkMedia(LINK_THIS,0,[PRIM_MEDIA_WHITELIST]), [HTTP_METHOD, "GET"], "");
	    }
	    if(!iIsChat) AuthMenu(kAv);
	    			
	}
	else if ((sCmd == g_sUnsetGroup) || (sCmd == "unsetgroup"))
	{
        llSetLinkMedia(LINK_THIS,0,[PRIM_MEDIA_WHITELIST,"",PRIM_MEDIA_AUTO_ZOOM,FALSE]);
        g_sGroupName = "";
        llMessageLinked(LINK_SET, SETTING_DELETE, "group", "");
        llMessageLinked(LINK_SET, SETTING_DELETE, "groupname", "");	
        Notify(kAv, "Group unset.", FALSE);
        if(!iIsChat) AuthMenu(kAv);
	}
	else if (sCmd == "setgroupname")
	{
        g_sGroupName = llDumpList2String(llList2List(lParams, 1, -1), " ");
        llMessageLinked(LINK_SET, SETTING_SAVE, "groupname=" + g_sGroupName, "");
	}
	else if ((sCmd == g_sSetOpenAccess) || (sCmd == "setopenaccess"))
	{
		llSetLinkMedia(LINK_THIS,0,[PRIM_MEDIA_AUTO_SCALE,TRUE]);
	    llMessageLinked(LINK_SET, SETTING_SAVE, "openaccess=" + (string)llGetLinkMedia(LINK_THIS,0,[PRIM_MEDIA_AUTO_SCALE]), "");
	    Notify(kAv, "Open access set.", FALSE);
        if(!iIsChat) AuthMenu(kAv);		
	}
	else if ((sCmd == g_sUnsetOpenAccess) || (sCmd == "unsetopenaccess"))
	{
    	llSetLinkMedia(LINK_THIS,0,[PRIM_MEDIA_AUTO_SCALE,FALSE]);
        llMessageLinked(LINK_SET, SETTING_DELETE, "openaccess", "");
        Notify(kAv, "Open access unset.", FALSE);
        if(!iIsChat) AuthMenu(kAv);		
	}
	else if ((sCmd == g_sSetLimitRange) || (sCmd == "setlimitrange"))
	{
        g_iLimitRange = TRUE;
        // as the default is range limit on, we do not need to store anything for this
        llMessageLinked(LINK_SET, SETTING_DELETE, "limitrange", "");
        Notify(kAv, "Range limited set.", FALSE);
        if(!iIsChat) AuthMenu(kAv);		
	}
	else if ((sCmd == g_sUnsetLimitRange) || (sCmd == "unsetlimitrange"))	
	{
        g_iLimitRange = FALSE;
        llMessageLinked(LINK_SET, SETTING_SAVE, "limitrange=" + (string) g_iLimitRange, "");
        Notify(kAv, "Range limited unset.", FALSE);
        if(!iIsChat) AuthMenu(kAv);		
	}
	else if ((sCmd == g_sListOwners) || (sCmd == "settings") || (sCmd == "listowners"))
	{
        Notify(kAv, "Owners: " + dumpList(OWNERLIST),FALSE);	
        Notify(kAv, "Secowners: " + dumpList(SECOWNERLIST),FALSE);
        Notify(kAv, "Black List: " + dumpList(BLACKLIST),FALSE);
        Notify(kAv, "Group: " + g_sGroupName,FALSE);
        Notify(kAv, "Group Key: " + (string)llGetLinkMedia(LINK_THIS,0,[PRIM_MEDIA_WHITELIST]),FALSE);
        Notify(kAv, "Open Access: " + dumpBool((integer)((string)llGetLinkMedia(LINK_THIS,0,[PRIM_MEDIA_AUTO_SCALE]))),FALSE);
        Notify(kAv, "LimitRange: "+ dumpBool(g_iLimitRange),FALSE);
		if(!iIsChat) AuthMenu(kAv);        
	}
	else if ((sCmd == g_sRunaway) || (sCmd == "runaway"))
	{
        Notify(g_kWearer, "Running away from all owners started, your owners will now be notified!",FALSE);
		NotifyOwners(llKey2Name(g_kWearer) + " has run away!");
        Notify(g_kWearer, "Runaway finished, the collar will now reset!",FALSE);
        // moved reset request from settings to here to allow noticifation of owners.
        llMessageLinked(LINK_SET, COMMAND_OWNER, "clear", kAv);    	
        llMessageLinked(LINK_SET, COMMAND_OWNER, "resetscripts", kAv);
        llResetScript();		
	}
}

//[g_sSetGroup,g_sUnsetGroup,g_sSetOpenAccess,g_sUnsetOpenAccess,g_sSetLimitRange,g_sUnsetLimitRange]

/*---------------//
//  HANDLERS     //
//---------------*/
// pragma inline
HandleSETTINGS(integer iSender, integer iNum, string sStr, key kID)
{
    if (iNum == SETTING_RESPONSE)
    {
        list lParams = llParseString2List(sStr, ["="], []);
        string sToken = llList2String(lParams, 0);
        string sValue = llList2String(lParams, 1);
        if (~llListFindList(g_lAuthTokens,[sToken]))
        {
        	setAuthList(llListFindList(g_lAuthTokens,[sToken]),llParseString2List(sValue, [","], [""]));
        }
        else if (sToken == "group")
        {
            llSetLinkMedia(LINK_THIS,0,[PRIM_MEDIA_WHITELIST,sValue]);
            //check to see if the object's group is set properly
            if ( (string)llGetLinkMedia(LINK_THIS,0,[PRIM_MEDIA_WHITELIST]) != "")
            {
                if ((key)llList2String(llGetObjectDetails(llGetKey(), [OBJECT_GROUP]), 0) == (string)llGetLinkMedia(LINK_THIS,0,[PRIM_MEDIA_WHITELIST]))
                {
                	llSetLinkMedia(LINK_THIS,0,[PRIM_MEDIA_AUTO_ZOOM,TRUE]);
                }
                else
                {
                	llSetLinkMedia(LINK_THIS,0,[PRIM_MEDIA_AUTO_ZOOM,FALSE]);
                }
            }
            else
            {
                llSetLinkMedia(LINK_THIS,0,[PRIM_MEDIA_AUTO_ZOOM,FALSE]);
            }
        }
        else if (sToken == "groupname")
        {
            g_sGroupName = sValue;
        }
        else if (sToken == "openaccess")
        {
        	llSetLinkMedia(LINK_THIS,0,[PRIM_MEDIA_AUTO_SCALE,sValue]);
        }
        else if (sToken == "limitrange")
        {
            g_iLimitRange = (integer)sValue;
        }
        else if (sToken == "prefix")
        {
            g_sPrefix = sValue;
        }
    }	
}

// pragma inline
HandleDIALOG(integer iSender, integer iNum, string sStr, key kID)
{      	
    if (iNum == DIALOG_RESPONSE)
    {	
        if (llListFindList([g_kAuthMenuID, g_kSensorMenuID], [kID]) != -1)
        {
            list lMenuParams = llParseString2List(sStr, ["|"], []);
           // string sJSON = llList2String(lMenuParams, 0);
            key kAv = llList2Key(lMenuParams, 0);
            string sMessage = llList2String(lMenuParams, 1);
            integer iPage = (integer)llList2String(lMenuParams, 2);
			Debug((string)kAv + "|" + (string)kID + "|" + (string)g_kAuthMenuID +"|" + sMessage);
            if (kID == g_kAuthMenuID)
            {
                //g_kAuthMenuID responds to setowner, setsecowner, setblacklist, remowner, remsecowner, remblacklist
                //setgroup, unsetgroup, setopenaccess, unsetopenaccess
                if (sMessage == UPMENU)
                {
                    llMessageLinked(LINK_SET, MENU_SUBMENU, g_sParentMenu, kAv);
                }
                Debug("CHECKAUTH: " + (string)CheckAuth(kAv,COMMAND_OWNER,COMMAND_OWNER,FALSE));
                if (CheckAuth(kAv,COMMAND_OWNER,COMMAND_OWNER,FALSE))
                {
                    if ((sMessage == g_sSetOwner) || (sMessage == g_sSetSecOwner) || (sMessage == g_sSetBlackList))
                    {
                        g_sRequestType = sMessage + "scan";
                        g_kDialoger = kAv;
                        llSensor("", "", AGENT, 10.0, PI);
                    }
                    else if (~llListFindList(g_lRemAuthTokens,[sMessage]))
                    {
                        RemPersonMenu(kAv, "sMessage");
                    }
	                else if (~llListFindList([g_sSetGroup,g_sUnsetGroup,g_sSetOpenAccess,g_sUnsetOpenAccess,g_sSetLimitRange,g_sUnsetLimitRange,g_sListOwners,g_sRunaway],[sMessage]))
	                {
	                	Debug("USER:" + sMessage);
	                	userCommand(sMessage,[] , kAv, FALSE);
	                } 	                
                }
                else
                {
                    Notify(kAv,"Sorry, only an owner can do that.", FALSE);
                }
            }
            else if (kID == g_kSensorMenuID)
            {
                if (sMessage != UPMENU)
                {
//#mdebug info                	
                    Debug(g_sRequestType);
//#enddebug                    
                    if (CheckAuth(kAv,COMMAND_OWNER,COMMAND_OWNER,FALSE))
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
                            if (~llListFindList(g_lRemAuthTokens,[g_sRequestType]))
                            {
                                sCmd += " " + llList2String(getAuthList(llListFindList(g_lRemAuthTokens,[g_sRequestType]),FALSE), (integer)sMessage*2 - 1);
                            }
                            llMessageLinked(LINK_SET, COMMAND_OWNER, sCmd, kAv);
                        }
                    }
                    if(endswith(g_sRequestType,"scan"))
                    {
                        if (~llListFindList(g_lAuthTokens,[StringReplace(g_sRequestType,"scan","")]))
                        {
                            llMessageLinked(LINK_SET, COMMAND_OWNER, StringReplace(g_sRequestType,"scan","") + " " + sMessage, kAv);                    
                        }
                    }
                }
                AuthMenu(kAv);
            }
        }
    }
}

// pragma inline
HandleMENU(integer iSender, integer iNum, string sStr, key kID)
{
	Debug("MENU: " + (string)g_kAuthMenuID + "|" + (string)kID + " | " + sStr);        	
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

// pragma inline
HandleCOMMAND(integer iSender, integer iNum, string sStr, key kID)
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
        integer iAuth = UserAuth(kID, TRUE);
        llMessageLinked(LINK_SET, iAuth, sStr, kID);
//#mdebug info        
        Debug("noauth: " + sStr + " from object " + (string)kID + " who has auth " + (string)iAuth);
//#enddebug        
    }
		       
    if (iNum == COMMAND_OWNER)
    { //respond to messages to set or unset owner, group, or secowners.  only owner may do these things
        list lParams = llParseString2List(sStr, [" "], []);
        string sCommand = llList2String(lParams, 0);
		integer iAuthIndex = llListFindList(g_lAuthTokens,[sCommand]);
		integer iRemAuthIndex = llListFindList(g_lRemAuthTokens,[sCommand]);
		list lTemp = ["", "Owner List", "Secondary Owner List", "Blacklist"];
		if (~iAuthIndex)
		{ 
		    g_sRequestType = sCommand;
		    //pop the command off the param list, leaving only first and last name
		    lParams = llDeleteSubList(lParams, 0, 0);
		    //record owner name
		    if (llGetListLength(lParams) == 1) lParams += ["Resident"];
		    g_sTmpName = llDumpList2String(lParams, " ");
		    //sensor for the owner name to get the key or set the owner directly if it is the wearer
		    if (g_sTmpName=="")
		    {
		        // If it was an "owner" command (iAuth = 1) and no name, show the menu
		        if (iAuthIndex == 1)
		        {
		            AuthMenu(kID);
		            return;
		        }
		        else
		        {
		            g_sRequestType += "scan";
		            g_kDialoger = kID;
		            llSensor("", "", AGENT, 10.0, PI);
		        }
		    }
		    else if (llGetListLength(getAuthList(iAuthIndex,FALSE)) == 20)
		    {
		        Notify(kID, "The maximum of 10 items in the "  + llList2String(lTemp,iAuthIndex) + " is reached, please clean up.",FALSE);
		    }
		    else
		    {    
		        if(llToLower(g_sTmpName) == llToLower(llKey2Name(g_kWearer)))
		        {
		            NewPerson(g_kWearer, g_sTmpName, sCommand);
		        }
		        else
		        {
		            g_kDialoger = kID;
		            llSensor("","", AGENT, 20.0, PI);
		        }
		    }
		}
		else if (~iRemAuthIndex)
		{ 
		    g_sRequestType = "";
		    //pop the command off the param list, leaving only first and last name
		    lParams = llDeleteSubList(lParams, 0, 0);
		    //name of person concerned
		    if (llGetListLength(lParams) == 1) lParams += ["Resident"];
		    g_sTmpName = llDumpList2String(lParams, " ");
		    if (g_sTmpName=="")
		    {
		        RemPersonMenu(kID, sCommand);
		    }
		    else if(llToLower(g_sTmpName) == "remove all")
		    {
		        Notify(kID, "Removal of all from the " + llList2String(lTemp,iRemAuthIndex) + " started!",TRUE);
		
		        NotifyInList(getAuthList(llListFindList(g_lRemAuthTokens,[sCommand]),FALSE), sCommand);
		
		        setAuthList(llListFindList(g_lRemAuthTokens,[sCommand]), []);		                
		        llMessageLinked(LINK_SET, SETTING_DELETE, sCommand, "");
		        
		        Notify(kID, llList2String(lTemp,iRemAuthIndex) + " has been cleared!",TRUE);
		    }
		    else
		    {
		         RemovePerson(g_sTmpName, sCommand, kID);
		    }
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
        integer iStop = llGetListLength(getAuthList(OWNERLIST,FALSE));
        for (n = 0; n < iStop; n += 2)
        {
            key kOwner = (key)llList2String(getAuthList(OWNERLIST,FALSE), n);
            Notify(kOwner, "Your sub " + sSubName + " has used the safeword. Please check on " + sSubFirstName +"'s well-being and if further care is required.",FALSE);
        }
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
        integer n;
        for (n=1;n<6;n++)
        {
        	setAuthList(n,[]);
        }
		llSetLinkMedia(LINK_THIS,0,[PRIM_MEDIA_WHITELIST,"",PRIM_MEDIA_AUTO_LOOP,FALSE,PRIM_MEDIA_AUTO_SCALE,FALSE,PRIM_MEDIA_AUTO_ZOOM,FALSE]);
     	
//#mdebug info    	
        Debug((string)llGetFreeMemory());
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
            HandleSETTINGS(iSender,iNum,sStr,kID);
        }
        else if ((iNum >= MENU_REQUEST) && (iNum <= MENU_REMOVE))
        {
            HandleMENU(iSender,iNum,sStr,kID); 
        }
        else if ((iNum >= DIALOG_REQUEST) && (iNum <= DIALOG_TIMEOUT))
        {
            HandleDIALOG(iSender,iNum,sStr,kID);
        }        
        else if ((iNum >= COMMAND_WEARERLOCKEDOUT) && (iNum <= COMMAND_OWNER))
        {
            HandleCOMMAND(iSender,iNum,sStr,kID);
        }    	
        else if (iNum == COMMAND_NOAUTH)
        {
            integer iAuth = UserAuth((string)kID, FALSE);
            {
                llMessageLinked(LINK_SET, iAuth, sStr, kID);
            }
//#mdebug info
            Debug("noauth: " + sStr + " from " + (string)kID + " who has auth " + (string)iAuth);
//#enddebug            
        }
        else if (iNum == WEARERLOCKOUT)
        {
        	// Wearer lockout generated by plugin.
            if (sStr == "on")
            {
            	llSetLinkMedia(LINK_THIS,0,[PRIM_MEDIA_AUTO_LOOP,TRUE]);              
            }
            else if (sStr == "off")
            {
            	llSetLinkMedia(LINK_THIS,0,[PRIM_MEDIA_AUTO_LOOP,FALSE]);              
            }
        }      
    }
    
    sensor(integer iNum_detected)
    {
		integer iAuthIndex;
		integer iScanAuthIndex;
        if(endswith(g_sRequestType,"scan"))
        {
            iScanAuthIndex = llListFindList(g_lAuthTokens,[StringReplace(g_sRequestType,"scan","")]);
        }
        else
        {
            iAuthIndex = llListFindList(g_lAuthTokens,[g_sRequestType]);
        }

        if(~iAuthIndex)
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
        else if(~iScanAuthIndex)
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
		integer iAuthIndex;
		integer iScanAuthIndex;
        if(endswith(g_sRequestType,"scan"))
        {
            iScanAuthIndex = llListFindList(g_lAuthTokens,[StringReplace(g_sRequestType,"scan","")]);
        }
        else
        {
            iAuthIndex = llListFindList(g_lAuthTokens,[g_sRequestType]);
        }
        
        if(~iAuthIndex)
        {
            //reformat name with + in place of spaces
            Name2Key(llDumpList2String(llParseString2List(g_sTmpName, [" "], []), "+"));
        }
        else if(~iScanAuthIndex)
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
                Debug(sBody);
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
