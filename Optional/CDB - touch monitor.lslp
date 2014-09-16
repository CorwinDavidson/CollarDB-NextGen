/*--------------------------------------------------------------------------------**
**  File: CDB - touch monitor                                                     **
** ------------------------------------------------------------------------------ **
**  Version: 6.00.001                                                             **
** ------------------------------------------------------------------------------ **
** Licensed under the GPLv2, with the additional requirement that these scripts   **
** remain "full perms" in Second Life®.  See "CollarDB License" for details.      **
** ------------------------------------------------------------------------------ **
** ©2014 CollarDB and Individual Contributors                                     **
**--------------------------------------------------------------------------------*/

// Description:
//
//  Uses OC Auth system to see if the person touching the collar is an Owner (Primary or Secondary) or if it is the wearer.
//  If it is not, the owners are sent an IM stating who touched the collar and who's collar it was that was touched.
//
//  There are currently no Menu Configurable items.

/*-------------//
//  VARIABLES  //
//-------------*/

string g_sSubMenu = "Touch";
string g_sParentMenu = "AddOns";
string g_sChatCommand = "touchmon";


key g_kMenuID;  // menu handler

integer g_iReshowMenu=FALSE; 


list g_lLocalbuttons = []; 


$import lib.MessageMap.lslm ();
$import lib.CommonVariables.lslm ();
$import lib.CommonFunctions.lslm ();

/*---------------//
//  MESSAGE MAP  //
//---------------*/


/*---------------//
//  FUNCTIONS    //
//---------------*/

DoMenu(key keyID)
{
    string sPrompt = "Touch Monitor 3.582\n\nUnauthorized touch's will be sent to all Primary and Secondary Owners\n\n";
    list lMyButtons = g_lLocalbuttons + g_lButtons;

    lMyButtons = llListSort(lMyButtons, 1, TRUE); 

    g_kMenuID = Dialog(keyID, sPrompt, lMyButtons, [UPMENU], 0);
}


/*---------------//
//  HANDLERS     //
//---------------*/
// pragma inline
HandleHTTPDB(integer iSender, integer iNum, string sStr, key kID)
{
    if ((iNum == SETTING_RESPONSE) || (iNum == SETTING_SAVE))
    {
        list lParams = llParseString2List(sStr, ["="], []);
        string sToken = llList2String(lParams, 0);
        string sValue = llList2String(lParams, 1);
        if (sToken == "owner")
        {
            g_lOwners = llParseString2List(sValue, [","], []);
        }
    }
}
// pragma inline
HandleDIALOG(integer iSender, integer iNum, string sStr, key kID)
{
    if (iNum == DIALOG_RESPONSE)
    {
        if (kID == g_kMenuID)
        {
            list lMenuParams = llParseString2List(sStr, ["|"], []);
            key kAv = (key)llList2String(lMenuParams, 0);
            string sMessage = llList2String(lMenuParams, 1);
            integer iPage = (integer)llList2String(lMenuParams, 2);
            if (sMessage == UPMENU)
            {
                llMessageLinked(LINK_THIS,MENU_SUBMENU, g_sParentMenu, kAv);
            }
            else if (~llListFindList(g_lLocalbuttons, [sMessage]))
            {
            }
            else if (~llListFindList(g_lButtons, [sMessage]))
            {
                llMessageLinked(LINK_THIS,MENU_SUBMENU, sMessage, kAv);
            }
        }
    }
    else if (iNum == DIALOG_TIMEOUT)
    {
        if (kID == g_kMenuID)
        {
//#mdebug info
            Debug("The user was to slow or lazy, we got a timeout!");
//#enddebug
        }
    }
}
// pragma inline
HandleMENU(integer iSender, integer iNum, string sStr, key kID)
{
    if (iNum ==MENU_SUBMENU)
    {
        if (sStr == g_sSubMenu)
        {
            DoMenu(kID);
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
    list lParams = llParseString2List(sStr, [" "], []);
    string sCommand = llToLower(llList2String(lParams, 0));
    string sValue = llToLower(llList2String(lParams, 1));
 
    if (iNum >= COMMAND_OWNER && iNum <= COMMAND_WEARER && iNum != COMMAND_GROUP)
        {
            if (sStr == g_sChatCommand)
            {
                DoMenu(kID);
            }
        }
        else if (iNum == COMMAND_EVERYONE || iNum == COMMAND_GROUP)
        {
            if (sStr == "touch")
            {           
                NotifyOwners(llKey2Name(kID) + " touched " + llKey2Name(llGetOwner()) + "'s Collar");
                Notify(g_kWearer, (string)llKey2Name(kID) + " touched your Collar.",FALSE);
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
        g_kWearer = llGetOwner();
        llSleep(1.0);
        llMessageLinked(LINK_THIS, MENU_REQUEST, g_sSubMenu, NULL_KEY);
        llMessageLinked(LINK_THIS, MENU_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, NULL_KEY);
    }

    on_rez(integer iParam)
    {
        if (llGetOwner()!=g_kWearer)
        {
            llResetScript();
        }
    }

    touch_start(integer total_number)
    {
        integer i = 0;
        string touchers;
        for (i=0;i < total_number; i++)
        {
            llMessageLinked(LINK_SET, COMMAND_NOAUTH, "touch", llDetectedKey(i));
        }
    }

    link_message(integer iSender, integer iNum, string sStr, key kID)
    {
        if ((iNum >= SETTING_SAVE) && (iNum <= SETTING_EMPTY))
        {
            HandleHTTPDB(iSender,iNum,sStr,kID);
        }
        else if ((iNum >= MENU_REQUEST) && (iNum <= MENU_REMOVE))
        {
            HandleMENU(iSender,iNum,sStr,kID); 
        }
        else if ((iNum >= DIALOG_TIMEOUT) && (iNum <= DIALOG_REQUEST))
        {
            HandleDIALOG(iSender,iNum,sStr,kID);
        }        
        else if ((iNum >= COMMAND_OWNER) && (iNum <= COMMAND_EVERYONE))
        {
            HandleCOMMAND(iSender,iNum,sStr,kID);
        }
    }    
}
