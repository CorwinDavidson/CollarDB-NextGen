/*--------------------------------------------------------------------------------**
**  File: CDB - interface                                                         **
** ------------------------------------------------------------------------------ **
**  Version: 6.00.001                                                             **
** ------------------------------------------------------------------------------ **
** Licensed under the GPLv2, with the additional requirement that these scripts   **
** remain "full perms" in Second Life®.  See "CollarDB License" for details.      **
** ------------------------------------------------------------------------------ **
** ©2014 CollarDB and Individual Contributors                                     **
**--------------------------------------------------------------------------------*/

// -- MENU GLOBALS --
//list g_lMenuNames = ["Main","Help/Debug","AddOns"];
//list g_lMenus;   //exists in parallel to g_lMenuNames, each entry containing a pipe-delimited string with the items for the corresponding menu
list g_lMenuCache = [
"Main","","Pick an option.\n",
"Help/Debug","","Click 'Guide' to receive a help notecard,\nClick 'ResetScripts' to reset the CollarDB scripts without losing your settings.\nClick any other button for a quick popup help about the chosen topic.\n",
"AddOns","","Please choose your AddOn:\n"
]; // Strided list to hold Menus

// list g_lMenuPrompts = [
// "Pick an option.\n",
//"Click 'Guide' to receive a help notecard,\nClick 'ResetScripts' to reset the CollarDB scripts without losing your settings.\nClick any other button for a quick popup //help about the chosen topic.\n",
//"Please choose your AddOn:\n"
//];

list g_lMenuIDs;   //3-strided list of avatars given menus, their dialog ids, and the name of the menu they were given
integer g_iMenuStride = 3;
integer g_iScriptCount;   //when the scriptcount changes, rebuild menus

string GIVECARD = "Guide";
string HELPCARD = "CollarDB Guide";
string REFRESH_MENU = "Fix Menus";
string RESET_MENU = "ResetScripts";
// -- MENU GLOBALS --

// -- DIALOG GLOBALS --
integer iPagesize = 12;
string MORE = ">";
string PREV = "<";
string BLANK = " ";
integer g_iTimeOut = 300;
integer g_iReapeat = 5;  //how often the timer will go off, in seconds

list g_lDialogs;  //6-strided list in form listenChan, dialogid, listener, starttime, recipient, prompt, list buttons, utility buttons, currentpage, button digits
//where "list buttons" means the big list of choices presented to the user
//and "page buttons" means utility buttons that will appear on every page, such as one saying "go up one level"
//and "currentpage" is an integer meaning which page of the menu the user is currently viewing

list g_lRemoteMenus;
integer g_iStrideLength = 6;


$import lib.MessageMap.lslm ();
$import lib.CommonVariables.lslm ();
$import lib.CommonFunctions.lslm ();



// -- MENU FUNCTIONS --

Menu(string sName, key kID)
{
    if( CacheValExists(g_lMenuCache,sName))
    {
        list lItems = llParseString2List(GetCacheVal(g_lMenuCache,sName,1),["|"],[]);
        string sPrompt = GetCacheVal(g_lMenuCache,sName,2);
        list lUtility = [];
        if (sName != "Main")
        {
            lUtility = [UPMENU];
        }
        key kMenuID = Dialog(kID, sPrompt, lItems, lUtility, 0);
        integer iIndex = llListFindList(g_lMenuIDs, [kID]);
        if (~iIndex)
        {
            //we've alread given a menu to this user.  overwrite their entry
            g_lMenuIDs = llListReplaceList(g_lMenuIDs, [kID, kMenuID, sName], iIndex, iIndex + g_iMenuStride - 1);
        }
        else
        {
            //we've not already given this user a menu. append to list
            g_lMenuIDs += [kID, kMenuID, sName];
        }
    }
}

MenuInit()
{
    integer n;
    integer iStop = llGetListLength(g_lMenuCache);
    for (n = 0; n < iStop; n=n+3)
    {
        string sName = llList2String(g_lMenuCache, n);
        if (sName != "Main")
        {
            //make each submenu appear in Main
            HandleMenuResponse("Main|" + sName);
            
            //request children of each submenu
            llMessageLinked(LINK_SET, MENU_REQUEST, sName, NULL_KEY);            
        }
    }
    //give the help menu GIVECARD and REFRESH_MENU buttons    
    HandleMenuResponse("Help/Debug|" + GIVECARD);
    HandleMenuResponse("Help/Debug|" + REFRESH_MENU);
    HandleMenuResponse("Help/Debug|" + RESET_MENU);       
    
    llMessageLinked(LINK_SET, MENU_REQUEST, "Main", ""); 
}

HandleMenuResponse(string entry)
{
    list lParams = llParseString2List(entry, ["|"], []);
    string sName = llList2String(lParams, 0);
    string g_sSubMenu = llList2String(lParams, 1);
    if (CacheValExists(g_lMenuCache, sName))
    {             
        list lGuts = llParseString2List(GetCacheVal(g_lMenuCache,sName,1),["|"],[]);
        if (llListFindList(lGuts, [g_sSubMenu]) == -1)
        {
            lGuts += [g_sSubMenu];
            lGuts = llListSort(lGuts, 1, TRUE);
            SetCacheVal(g_lMenuCache,sName,llDumpList2String(lGuts, "|"),1);
        }
    }    
}
// -- MENU FUNCTIONS --


// -- DIALOG FUNCTIONS -- 
string Key2Name(key kId)
{
    string sOut = llGetDisplayName(kId);
    if (sOut) return sOut;
    else return llKey2Name(kId);
}

string Integer2String(integer iNum, integer iDigits)
{
    string sOut = "";
    integer i;
    for (i = 0; i <iDigits; i++) {
        sOut = (string) (iNum%10) + sOut;
        iNum /= 10;
    }
    return sOut;
}

integer GetStringBytes(string sStr) { // from SL wiki
    sStr = llEscapeURL(sStr);
    integer i = 0;
    integer j;
    integer l = llStringLength(sStr);
     list lAtoms = llParseStringKeepNulls(sStr, ["%"], []);
    return l - 2 * llGetListLength(lAtoms) + 2;

/* too slow!
    for (j = l; j > -1; j--)
        if (llGetSubString(sStr, j, j) == "%") i++;
    return l - i - i;*/
}

string TruncateString(string sStr, integer iBytes){
    sStr = llEscapeURL(sStr);
    integer j;
    string sOut;
    integer l = llStringLength(sStr);
    for (j = 0; j < l; j++)
    {  
        string c = llGetSubString(sStr, j, j);
        if (c == "%") {
            if (iBytes >= 2) {
                sOut += llGetSubString(sStr, j, j+2);
                j += 2;
                iBytes -= 2;
            }
        }
        else {
            if (iBytes >= 1) {
                sOut += c;
                iBytes --;
            }
        }
    }
    return llUnescapeURL(sOut);
}


integer ButtonDigits(list lIn)
// checks if any of the times is over 20 characters and deduces how many digits are needed
{
    integer m=llGetListLength(lIn);
    integer iDigits;
    if ( m < 10 ) iDigits = 1;
    else if (m < 100) iDigits = 2;
    else if (m < 1000) iDigits = 3; // more than 100 is unlikely, considering the size of a LM
    integer i;
    for (i=0;i<m;i++) if (GetStringBytes(llList2String(lIn,i))>18) return iDigits;
    return 0; // if no button label is too long, then no need for any digit
}

integer RandomUniqueChannel()
{
    integer iOut = llRound(llFrand(10000000)) + 100000;
    if (~llListFindList(g_lDialogs, [iOut]))
    {
        iOut = RandomUniqueChannel();
    }
    return iOut;
}

//Dialog(key kRecipient, string sPrompt, list lMenuItems, list lUtilityButtons, integer iPage, key kID, integer iWithNums)
GenDialog(string sJSONRequest, key kID)
{
    key kRecipient = llJsonGetValue ( sJSONRequest, [ "DIALOG", 0 ] );
    string sPrompt = llJsonGetValue ( sJSONRequest, [ "DIALOG", 1 ] );
    integer iPage = (integer)llJsonGetValue ( sJSONRequest, [ "DIALOG", 2 ] );
    list lMenuItems = llParseString2List(llJsonGetValue ( sJSONRequest, [ "DIALOG", 3 ] ), ["`"], []);
    list lUtilityButtons = llParseString2List(llJsonGetValue ( sJSONRequest, [ "DIALOG", 4 ] ), ["`"], []); 
    
    integer iWithNums = ButtonDigits(lMenuItems);
    
    string sThisPrompt = " \n(Timeout in "+ (string)g_iTimeOut +" seconds.)";
    string sButtonPrompt = "\n \n";
    list lButtons;
    list lCurrentItems;
    integer iNumitems = llGetListLength(lMenuItems);
    integer iStart;
    integer iMyPageSize = iPagesize - llGetListLength(lUtilityButtons);
        
    //slice the menuitems by page
    if (iNumitems > iMyPageSize)
    {
        iMyPageSize=iMyPageSize-2;//we'll use two slots for the MORE and PREV button, so shrink the page accordingly
        iStart = iPage * iMyPageSize;
        //multi page menu
        sThisPrompt = " --- Page "+(string)(iPage+1)+"/"+(string)(((iNumitems-1)/iMyPageSize)+1);
    }
    else iStart = 0;
    integer iEnd = iStart + iMyPageSize - 1;
    if (iEnd >= iNumitems) iEnd = iNumitems - 1;
    if (iWithNums) { // put numbers in front of buttons: "00 Button1", "01 Button2", ...
        integer iCur; for (iCur = iStart; iCur <= iEnd; iCur++) {
            string sButton = llList2String(lMenuItems, iCur);
            if ((key)sButton) sButton = Key2Name((key)sButton);
            sButton = Integer2String(iCur, iWithNums) + " " + sButton;
            sButtonPrompt = sButtonPrompt + sButton + "\n";
            sButton = TruncateString(sButton, 24);
            lButtons += [sButton];
        }
    }
    else if (iNumitems > iMyPageSize) lButtons = llList2List(lMenuItems, iStart, iEnd);
    else lButtons = lMenuItems;
    sThisPrompt = sButtonPrompt + sThisPrompt;
    // check prompt lengths
    integer iPromptlen=GetStringBytes(sPrompt);
    if (iPromptlen>511)
    {
        Notify(kRecipient,"The dialog prompt message is longer than 512 characters. It will be truncated to 512 characters.",TRUE);
        sPrompt=TruncateString(sPrompt,510);
        sThisPrompt = sPrompt;
    }
    else if (iPromptlen + GetStringBytes(sThisPrompt)< 512)
    {
        sThisPrompt= sPrompt + sThisPrompt;
    }
    else
    {
        sThisPrompt= sPrompt;
    }
       
    integer iChan = RandomUniqueChannel();
    integer g_iListener = llListen(iChan, "", kRecipient, "");
    llSetTimerEvent(g_iReapeat);
    if (iNumitems > iMyPageSize)
    {
        llDialog(kRecipient, sThisPrompt, PrettyButtons(lButtons, lUtilityButtons,[PREV,MORE]), iChan);      
    }
    else
    {
        llDialog(kRecipient, sThisPrompt, PrettyButtons(lButtons, lUtilityButtons,[]), iChan);
    }    
    integer ts = llGetUnixTime() + g_iTimeOut;
    g_lDialogs += [iChan, kID, g_iListener, ts, sJSONRequest];
}

list PrettyButtons(list lOptions, list lUtilityButtons, list iPagebuttons)
{//returns a list formatted to that "options" will start in the top left of a dialog, and "utilitybuttons" will start in the bottom right
    list lSpacers;
    list lCombined = lOptions + lUtilityButtons + iPagebuttons;
    while (llGetListLength(lCombined) % 3 != 0 && llGetListLength(lCombined) < 12)    
    {
        lSpacers += [BLANK];
        lCombined = lOptions + lSpacers + lUtilityButtons + iPagebuttons;
    }
    // check if a UPBUTTON is present and remove it for the moment
    integer u = llListFindList(lCombined, [UPMENU]);
    if (u != -1)
    {
        lCombined = llDeleteSubList(lCombined, u, u);
    }
    
    list lOut = llList2List(lCombined, 9, 11);
    lOut += llList2List(lCombined, 6, 8);
    lOut += llList2List(lCombined, 3, 5);    
    lOut += llList2List(lCombined, 0, 2);    

    //make sure we move UPMENU to the lower right corner
    if (u != -1)
    {
        lOut = llListInsertList(lOut, [UPMENU], 2);
    }

    return lOut;    
}


list RemoveMenuStride(list lMenu, integer iIndex)
{
    //tell this function the menu you wish to remove, identified by list index
    //it will close the listener, remove the menu's entry from the list, and return the new list
    //should be called in the listen event, and on menu timeout    
    integer g_iListener = llList2Integer(lMenu, iIndex + 2);
    llListenRemove(g_iListener);
    return llDeleteSubList(lMenu, iIndex, iIndex + g_iStrideLength - 1);
}

CleanList()
{
//#mdebug info	
//@    Debug("cleaning list");
//#enddebug    
    //loop through menus and remove any whose timeouts are in the past
    //start at end of list and loop down so that indices don't get messed up as we remove items
    integer iLength = llGetListLength(g_lDialogs);
    integer n;
    integer iNow = llGetUnixTime();
    for (n = iLength - g_iStrideLength; n >= 0; n -= g_iStrideLength)
    {
        integer iDieTime = llList2Integer(g_lDialogs, n + 3);
        //Debug("dietime: " + (string)iDieTime);
        if (iNow > iDieTime)
        {
//#mdebug info	        	
//@            Debug("menu timeout");
//#enddebug                            
            key kID = llList2Key(g_lDialogs, n + 1);
            llMessageLinked(LINK_SET, DIALOG_TIMEOUT, "", kID);
            g_lDialogs = RemoveMenuStride(g_lDialogs, n);
        }            
    } 
}

ClearUser(key kRCPT)
{
    //find any strides belonging to user and remove them
    integer iIndex = llListFindList(g_lDialogs, [kRCPT]);
    while (~iIndex)
    {
//#mdebug info	    	
//@        Debug("removed stride for " + (string)kRCPT);
//#enddebug        
          g_lDialogs = RemoveMenuStride(g_lDialogs, iIndex -4);
        //g_lDialogs = llDeleteSubList(g_lDialogs, iIndex - 4, iIndex - 5 + g_iStrideLength);
        iIndex = llListFindList(g_lDialogs, [kRCPT]);
    }
//#mdebug info	    
//@    Debug(llDumpList2String(g_lDialogs, ","));
//#enddebug	    
}

// -- DIALOG FUNCTIONS -- 


/*---------------//
//  MAIN CODE    //
//---------------*/
default
{    
    state_entry()
    {
    	g_lCacheTemplate =["",""];
        g_kWearer=llGetOwner();
        llSleep(1.0);   //delay sending this message until we're fairly sure that other scripts have reset too, just in case
        g_iScriptCount = llGetInventoryNumber(INVENTORY_SCRIPT);
        MenuInit();  
    }

    touch_start(integer iNum)
    {
        llMessageLinked(LINK_SET, COMMAND_NOAUTH, "menu", llDetectedKey(0));
    }
    
    link_message(integer iSender, integer iNum, string sStr, key kID)
    {
        if ((iNum >= MENU_REQUEST) && (iNum <= MENU_REMOVE))
        {
            if (iNum == MENU_SUBMENU)
            {
                if (llListFindList(g_lMenuCache, [sStr]) != -1)
                {
                    Menu(sStr, kID);
                }
            }
            else if (iNum == MENU_REMOVE)
            {
                //sStr should be in form of parentmenu|childmenu
                list lParams = llParseString2List(sStr, ["|"], []);
                string parent = llList2String(lParams, 0);
                string child = llList2String(lParams, 1);
                integer iMenuIndex = llListFindList(g_lMenuCache, [parent]);
                if (iMenuIndex != -1)
                {
                    list lGuts = llParseString2List(llList2String(g_lMenuCache, iMenuIndex), ["|"], []);
                    integer gutiIndex = llListFindList(lGuts, [child]);
                    //only remove if it's there
                    if (gutiIndex != -1)        
                    {
                        lGuts = llDeleteSubList(lGuts, gutiIndex, gutiIndex);
                        g_lMenuCache = llListReplaceList(g_lMenuCache, [llDumpList2String(lGuts, "|")], iMenuIndex, iMenuIndex);                    
                    }        
                }
            }    
            else if (iNum == MENU_RESPONSE)
            {
                //sStr will be in form of "parent|menuname"
                //ignore unless parent is in our list of menu names
                HandleMenuResponse(sStr);
            }
        }
        else if ((iNum >= DIALOG_REQUEST) && (iNum <= DIALOG_TIMEOUT))
        {
//#mdebug info	        	
//@            Debug("DIALOG REQUEST: " + sStr);
//#enddebug	            
            if (iNum == DIALOG_REQUEST)
            {
                key kRCPT = llJsonGetValue ( sStr, [ "DIALOG", 0 ] );
                integer iIndex = llListFindList(g_lRemoteMenus, [kRCPT]);
                if (~iIndex)
                {
                    if (!KeyIsAv(kRCPT))  //Only True if it is an AV and In the same Sim
                    {
                        llHTTPRequest(llList2String(g_lRemoteMenus, iIndex+1), [HTTP_METHOD, "POST"], sStr+"|"+(string)kID);
                        return;
                    }
                    else
                    {
                        g_lRemoteMenus = llListReplaceList(g_lRemoteMenus, [], iIndex, iIndex+1);
                    }
                }
                
                //first clean out any strides already in place for that user.  prevents having lots of listens open if someone uses the menu several times while sat
                ClearUser(kRCPT);
                
                //now give the dialog and save the new stride
                // Dialog(kRCPT, sPrompt, lButtons, uButtons, iPage, kID, iDigits);
                
                GenDialog(sStr,kID);
            }
            else if (iNum == DIALOG_RESPONSE)
            {
                integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
                if (iMenuIndex != -1)
                {
                    //got a menu response meant for us.  pull out values
                    list lMenuParams = llParseString2List(sStr, ["|"], []);
                    key kAv = (key)llList2String(lMenuParams, 0);          
                    string sMessage = llList2String(lMenuParams, 1);                                         
                    integer iPage = (integer)llList2String(lMenuParams, 2);
                    
                    //remove stride from g_lMenuIDs
                    //we have to subtract from the index because the dialog id comes in the middle of the stride
                    g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex - 2 + g_iMenuStride);                
                    
                    //process response
                    if (sMessage == UPMENU)
                    {
                        Menu("Main", kAv);
                    }
                    else
                    {
                        if (sMessage == GIVECARD)
                        {
                            llMessageLinked(LINK_SET, COMMAND_NOAUTH, "help", kAv);
                            Menu("Help/Debug", kAv);
                        }
                        else if (sMessage == REFRESH_MENU)
                        {//send a command telling other plugins to rebuild their menus
                            llMessageLinked(LINK_SET, COMMAND_NOAUTH, "refreshmenu", kAv);
                        }
                        else if (sMessage == RESET_MENU)
                        {//send a command to reset scripts
                            llMessageLinked(LINK_SET, COMMAND_NOAUTH, "resetscripts", kAv);
                        }
                        else
                        {
                            llMessageLinked(LINK_SET, MENU_SUBMENU, sMessage, kAv);
                        }
                    }
                }
            }
            else if (iNum == DIALOG_TIMEOUT)
            {
                integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
                //remove stride from g_lMenuIDs
                //we have to subtract from the index because the dialog id comes in the middle of the stride
                g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex - 2 + g_iMenuStride);                        
            }
        }        
        else if ((iNum >= COMMAND_WEARER) && (iNum <= COMMAND_OWNER))
        {
//#mdebug info	        	
//@            Debug(sStr);
//#enddebug	            
            list lParams = llParseString2List(sStr, [" "], []);
            string sCmd = llList2String(lParams, 0);
            string sValue = llToLower(llList2String(lParams, 1));
            if (sStr == "menu")
            {
                Menu("Main", kID);
            }
            else if (sStr == "help")
            {
                llGiveInventory(kID, HELPCARD);                
            }
            if (sStr == "addons")
            {
                Menu("AddOns", kID);
            }
            if (sStr == "debug")
            {
               Menu("Help/Debug", kID);
            }
            else if (sCmd == "menuto")
            {
                key kAv = (key)llList2String(lParams, 1);
                if (KeyIsAv(kAv))
                {
                    Menu("Main", kAv);
                }
            }
            else if (sCmd == "refreshmenu")
            {
                llDialog(kID, "Rebuilding menu.  This may take several seconds.", [], -341321);
                //MenuInit();
                llResetScript();
            }
        }
        else if (llGetSubString(sStr, 0, 10) == "remotemenu:")
        {
            if (iNum == COMMAND_OWNER || iNum == COMMAND_SECOWNER)
            {
                string sCmd = llGetSubString(sStr, 11, -1);
//#mdebug info	                
//@                Debug("dialog cmd:" + sCmd);
//#enddebug	                
                if (llGetSubString(sCmd, 0, 3) == "url:")
                {
                    integer iIndex = llListFindList(g_lRemoteMenus, [kID]);
                    if (~iIndex)
                    {
                        g_lRemoteMenus = llListReplaceList(g_lRemoteMenus, [kID, llGetSubString(sCmd,  4, -1)], iIndex, iIndex+1);
                    }
                    else
                    {
                        g_lRemoteMenus += [kID, llGetSubString(sCmd, 4, -1)];
                    }
                    llMessageLinked(LINK_SET, iNum, "menu", kID);
                }
                else if (llGetSubString(sCmd, 0, 2) == "off")
                {
                    integer iIndex = llListFindList(g_lRemoteMenus, [kID]);
                    if (~iIndex)
                    {
                        g_lRemoteMenus = llListReplaceList(g_lRemoteMenus, [], iIndex, iIndex+1);
                    }
                }
                else if (llGetSubString(sCmd, 0, 8) == "response:")
                {
                    list lParams = llParseString2List(llGetSubString(sCmd, 9, -1), ["|"], []);
                    //llMessageLinked(LINK_SET, DIALOG_RESPONSE, (string)kAv + "|" + sMessage + "|" + (string)iPage, kMenuID);
                    llMessageLinked(LINK_SET, DIALOG_RESPONSE, llList2String(lParams, 0) + "|" + llList2String(lParams, 1) + "|" + llList2String(lParams, 2), llList2String(lParams, 3));
                }
                else if (llGetSubString(sCmd, 0, 7) == "timeout:")
                {
                    llMessageLinked(LINK_SET, DIALOG_TIMEOUT, "", llGetSubString(sCmd, 8, -1));
                }
            }
        }
    }
      
    listen(integer iChan, string sName, key kID, string sMessage)
    {
        integer iMenuIndex = llListFindList(g_lDialogs, [iChan]);
        if (~iMenuIndex)
        {
            key kMenuID = llList2Key(g_lDialogs, iMenuIndex + 1);
            key kAv = llList2Key(g_lDialogs, iMenuIndex + 4);
            string sDialogJSON = llList2String(g_lDialogs, iMenuIndex + 5); 
            
            string sPrompt = llJsonGetValue ( sDialogJSON, [ "DIALOG", 1 ] );
            integer iPage = (integer)llJsonGetValue ( sDialogJSON, [ "DIALOG", 2 ] ); 
            list items = llParseString2List(llJsonGetValue ( sDialogJSON, [ "DIALOG", 3 ] ), ["`"], []);
            list uButtons = llParseString2List(llJsonGetValue ( sDialogJSON, [ "DIALOG", 4 ] ), ["`"], []); 
    
            integer iDigits = ButtonDigits(items);
            
            g_lDialogs = RemoveMenuStride(g_lDialogs, iMenuIndex);       
                   
            if (sMessage == MORE)
            {
                //increase the page num and give new menu
                iPage++;
                integer thisiPagesize = iPagesize - llGetListLength(uButtons) - 2;
                if (iPage * thisiPagesize >= llGetListLength(items))
                {
                    iPage = 0;
                }
            }
            else if (sMessage == PREV)
            {
                //increase the page num and give new menu
                iPage--;

                if (iPage < 0)
                {
                    integer thisiPagesize = iPagesize - llGetListLength(uButtons) - 2;

                    iPage = (llGetListLength(items)-1)/thisiPagesize;
                }
            }
            else if (sMessage == BLANK)         
            {
                //give the same menu back
            }            
            else
            {   
                string sAnswer;
                integer iIndex = llListFindList(uButtons, [sMessage]);
                if (iDigits && !~iIndex)
                {
                    integer iBIndex = (integer) llGetSubString(sMessage, 0, iDigits);
                    sAnswer = llList2String(items, iBIndex);
                }
                else sAnswer = sMessage;
                llMessageLinked(LINK_SET, DIALOG_RESPONSE, (string)kAv + "|" + sAnswer + "|" + (string)iPage, kMenuID);
                return;
            }  
            GenDialog(llJsonSetValue(sDialogJSON, [2, "DIALOG"], (string)iPage),kID);
        }
    }

    on_rez(integer iParam)
    {
        llResetScript();
    }
    
    changed(integer iChange)
    {
        if (iChange & CHANGED_INVENTORY)
        {
            if (llGetInventoryNumber(INVENTORY_SCRIPT) != g_iScriptCount)
            {//a script has been added or removed.  Reset to rebuild menu
                llResetScript();
            }
        }
    }
    
    timer()
    {
        CleanList();    
        
        //if list is empty after that, then stop timer
        
        if (!llGetListLength(g_lDialogs))
        {
//#mdebug info	        	
//@            Debug("no active dialogs, stopping timer");
//#enddebug	            
            llSetTimerEvent(0.0);
        }
    }
}
