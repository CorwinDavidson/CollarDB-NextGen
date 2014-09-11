/*--------------------------------------------------------------------------------**
**  File: CDB - attachment                                                             **
** ------------------------------------------------------------------------------ **
**  Version: 6.00.001                                                             **
** ------------------------------------------------------------------------------ **
** Licensed under the GPLv2, with the additional requirement that these scripts   **
** remain "full perms" in Second Life®.  See "CollarDB License" for details.      **
** ------------------------------------------------------------------------------ **
** ©2014 CollarDB and Individual Contributors                                     **
**--------------------------------------------------------------------------------*/

//---------------------
// Bridge Interface For Attachments
//---------------------

integer debug = FALSE;

string g_sSubMenu = "Attachments";
string g_sParentMenu = "Main";
list g_lLocalButtons = [];

integer g_iRemenu;
key g_kMenuID;

list messages = [];


//list nopass = [0,42,499,506,507,500,501,502,503,504,2000,2001,2003,6000,6010,602,3000,3001,3002,3003,-9000,-9001];
//list nopass = [0xCDB000,0xCDB042,0xCDB499,0xCDB506,0xCDB507,0xCDB500,0xCDB501,0xCDB502,0xCDB503,0xCDB504,0xCDB200,0xCDB201,0xCDB203,0xCDB250,0xCDB251,0xCDB253,0xCDB600,0xCDB601,-0xCDB610,-0xCDB699,0xCDB300,0xCDB301,0xCDB302,0xCDB303,-0xCDB900,-0xCDB901];

//MESSAGE MAP

$import lib.MessageMap.lslm ();
$import lib.CommonVariables.lslm ();
$import lib.CommonFunctions.lslm ();

list nopass = [COMMAND_NOAUTH,COMMAND_COLLAR,COMMAND_OBJECT,COMMAND_RLV_RELAY,COMMAND_OWNER,COMMAND_SECOWNER,COMMAND_GROUP,COMMAND_WEARER,COMMAND_EVERYONE,SETTING_SAVE,SETTING_REQUEST,SETTING_DELETE,RLV_CMD,RLV_REFRESH,ATTACHMENT_PASSTHROUGH,ATTACHMENT_PING,MENU_REQUEST,MENU_RESPONSE,MENU_SUBMENU,MENU_REMOVE,DIALOG_REQUEST,DIALOG_RESPONSE];


//added for attachment auth
integer g_iInterfaceChannelHandler = 0;
integer g_iPrevInterfaceChannelHandler = 0;
integer g_iInterfaceChannel = -12587429;
integer g_iCmdChannelOffset = 0xCDBC01; 

//------BRIDGE COMMAND---------
list g_lAttDialogKeyID;
list g_lAttMenu;
//-----------------------------


DoMenu(key kAv)
{
    list lMyButtons;
    string sPrompt;
 
    sPrompt = "Select the Attachment you would like to view the Menu for.";
  
    lMyButtons += llListSort(g_lLocalButtons + g_lButtons, 1, TRUE);
 
    g_kMenuID = Dialog(kAv, sPrompt, lMyButtons, [UPMENU], 0);
}

BridgePassthrough(string sStr, key kID)
{
    messages += [sStr];
    list lParts = llParseStringKeepNulls(sStr, ["¿"], []);
    string rNum = llList2String(lParts,0);
    string sCmd = llList2String(lParts,1);
    list lParams = llParseStringKeepNulls(sCmd, ["¥"], []);
    integer iParamNum = llList2Integer(lParams,0);
    string sParamStr =  llList2String(lParams,1);
    key kParamID = llList2Key(lParams,2);
    llMessageLinked(LINK_SET,iParamNum,sParamStr,kParamID);
    if (iParamNum == DIALOG_REQUEST)
    {
        integer idx = llListFindList(g_lAttDialogKeyID,[kID]);
        if (idx != -1)
        {                    
            g_lAttDialogKeyID = llDeleteSubList(g_lAttDialogKeyID,idx,idx+1);
        }        
        
        g_lAttDialogKeyID += [kID,kParamID];        
    }    
    else if (iParamNum == MENU_RESPONSE)
    {
        list lMenu = llParseStringKeepNulls(sParamStr, ["|"], []);
        string sParentmenu = llList2String(lMenu,0);
        string sSubmenu = llList2String(lMenu,1);
        g_lAttMenu += [kID,sParentmenu,sSubmenu];
    }

}

integer fromAttachment(integer iNum, string sStr, key id)
{
    integer rtnCode = TRUE;
    string cmd = (string)ATTACHMENT_PASSTHROUGH + "¿" + (string)iNum + "¥" + sStr + "¥" + (string)id;
    integer idx;
    idx = llListFindList(messages,[cmd]);
    if (idx != -1)
    {
        rtnCode = TRUE;
        messages = ListItemDelete(messages, cmd);
    }
    else
    { 
        rtnCode = FALSE;
    }
    
    return rtnCode;
    
}

list ListItemDelete(list mylist,string element_old) {
    integer placeinlist = llListFindList(mylist, [element_old]);
    if (placeinlist != -1)
        return llDeleteSubList(mylist, placeinlist, placeinlist);
    return mylist;
}


BridgeResponse(integer iSender, integer iNum, string sStr, key kID)
{
    if (llListFindList(nopass,[iNum]) == -1)
    {
        llWhisper(g_iInterfaceChannel, (string)COLLAR_PASSTHROUGH + "¿" + (string)iNum + "¥" +  sStr  + "¥" +  (string)kID);
    }
    else if (iNum == DIALOG_RESPONSE)
    {
            integer idx = llListFindList(g_lAttDialogKeyID,[kID]);        
            if (idx != -1)
            {   
                //sStr = StringReplace(sStr,"|","~");
                //string kObjectID = llList2String(g_lAttMenu,idx-1); 
                string kObjectID = llList2String(g_lAttDialogKeyID,idx-1);                 
               // llWhisper(g_iInterfaceChannel, "Command|" + (string)DIALOG_RESPONSE + "|" + sStr + "|" + (string)kID);
               llRegionSayTo((key)kObjectID, g_iInterfaceChannel, (string)COLLAR_PASSTHROUGH + "¿" + (string)iNum + "¥" +  sStr  + "¥" +  (string)kID);
                g_lAttDialogKeyID = llDeleteSubList(g_lAttDialogKeyID,idx-1,idx);
            }
            else
            {
                list lParams = llParseStringKeepNulls(sStr,["|"],[]);
                key kAV = llList2Key(lParams,0);
                string sItem = llList2String(lParams,1);
                idx = llListFindList(g_lAttMenu,[sItem]);
                if(idx != -1)
                {   
                    if((idx+1)%3 == 0)
                    {
                        string kObjectID = llList2String(g_lAttMenu,idx-2); 
                        //llRegionSayTo((key)kObjectID,g_iInterfaceChannel, "Command|" + (string)SUBMENU + "|" + (string)kAV + "~" + sItem + "~0|" + (string)kAV);
                        llRegionSayTo((key)kObjectID,g_iInterfaceChannel, (string)COLLAR_PASSTHROUGH + "¿" + (string)iNum + "¥" +  sStr  + "¥" +  (string)kID);                  
                    }
                }
            } 
            return;
    }
    else if (iNum == MENU_REQUEST)
    {
        integer idx;
        integer len;        
        list buffer = g_lAttMenu;
        if (sStr == g_sSubMenu)
        {
            llWhisper(g_iInterfaceChannel, (string)COLLAR_PASSTHROUGH + "¿" + (string)iNum + "¥" +  sStr  + "¥" +  (string)kID);
        }
        else if (llGetListLength(g_lAttMenu) > 0)
        {
            integer count;
            @loop;
            count = count + 1;      
            idx = llListFindList(buffer,[sStr]);
            if(idx != -1)
            {
                len = llGetListLength(buffer);
                string sParentmenu = llList2String(buffer,idx);
                string sSubmenu = llList2String(buffer,idx+1);                
                llMessageLinked(LINK_SET, MENU_RESPONSE, sStr + "|" + llList2String(buffer,idx+1), NULL_KEY);                
                buffer = llList2List(buffer,idx+2,len-1);
                jump loop;
            }    
        }
    }
   else if (iNum == MENU_RESPONSE)
    {
        list lParts = llParseStringKeepNulls(sStr, ["|"], []);
        if (llList2String(lParts, 0) == g_sSubMenu)
        {//someone wants to stick something in our menu
            string button = llList2String(lParts, 1);
            if (llListFindList(g_lButtons, [button]) == -1)
            {
                g_lButtons = llListSort(g_lButtons + [button], 1, TRUE);
            }
        }
    }
    else if (iNum == MENU_REMOVE)
    {
        //sStr should be in form of parentmenu|childmenu
        list lParams = llParseStringKeepNulls(sStr, ["|"], []);
        string child = llList2String(lParams, 1);
        if (llList2String(lParams, 0)==g_sSubMenu)
        {
            integer iIndex = llListFindList(g_lButtons, [child]);
            //only remove if it's there
            if (iIndex != -1)
            {
                g_lButtons = llDeleteSubList(g_lButtons, iIndex, iIndex);
            }
        }
    }    
    else if (iNum ==MENU_SUBMENU)
    {
        integer idx = llListFindList(g_lAttMenu,[sStr]);
        if(idx != -1)
        {   
            if((idx+1)%3 == 0)
            {
                string kObjectID = llList2String(g_lAttMenu,idx-2);        
                llRegionSayTo((key)kObjectID,g_iInterfaceChannel, "Command|" + (string)MENU_SUBMENU + "|" + (string)kID + "¥" + sStr + "¥0|" + (string)kID);
            }
        }
    }    
}


resetInterfaceChannel()
{
    llOwnerSay("reset_channel");
    key groupKey = llList2Key(llGetObjectDetails(llGetLinkKey(LINK_THIS), [OBJECT_GROUP]), 0);
    key parcelID = llList2Key(llGetParcelDetails(llGetPos(), [PARCEL_DETAILS_ID]),0);

    g_iInterfaceChannel= GetOwnerChannel(llGetOwner(),GetOwnerChannel(parcelID,GetOwnerChannel(groupKey,g_iCmdChannelOffset)));        
    
    if (g_iPrevInterfaceChannelHandler != 0)
    {
        llListenRemove(g_iPrevInterfaceChannelHandler);
    }
    g_iPrevInterfaceChannelHandler = g_iInterfaceChannelHandler;
    g_iPrevInterfaceChannelHandler = llListen(g_iInterfaceChannel, "", "", "");
}

default
{
    state_entry()
    {
        g_kWearer = llGetOwner();

        resetInterfaceChannel();
        
        messages = [];
        llSetTimerEvent(5.0);
    }
    
    listen(integer iChan, string sName, key kID, string sMsg)
    {
        llOwnerSay(sMsg);
        if (iChan == g_iInterfaceChannel)
        {
            list lParts = llParseStringKeepNulls(sMsg, ["|"], []);
            if ((integer)llList2String(lParts,0) == ATTACHMENT_PASSTHROUGH)
            {
                BridgePassthrough(sMsg,kID);
            }            
        }
    }
    
    link_message(integer iSender, integer iNum, string sStr, key kID)
    {
        if (iNum ==MENU_SUBMENU && sStr == g_sSubMenu)
        {
            //someone asked for our menu
            //give this plugin's menu to id
            g_iRemenu = TRUE;
            llMessageLinked(LINK_SET, COMMAND_NOAUTH, llToLower(g_sSubMenu),kID);
            return;
        }        
        else if (iNum == MENU_REQUEST && sStr == g_sParentMenu)
        {
            llMessageLinked(LINK_SET, MENU_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, NULL_KEY);
            return;
        }
        else if (iNum == MENU_RESPONSE)
        {
            list lParts = llParseStringKeepNulls(sStr, ["|"], []);
            if (llList2String(lParts, 0) == g_sSubMenu)
            {//someone wants to stick something in our menu
                string button = llList2String(lParts, 1);
                if (llListFindList(g_lButtons, [button]) == -1)
                {
                    g_lButtons = llListSort(g_lButtons + [button], 1, TRUE);
                }
            }
        }
        else if (iNum == MENU_REMOVE)
        {
            //sStr should be in form of parentmenu|childmenu
            list lParams = llParseStringKeepNulls(sStr, ["|"], []);
            string child = llList2String(lParams, 1);
            if (llList2String(lParams, 0)==g_sSubMenu)
            {
                integer iIndex = llListFindList(g_lButtons, [child]);
                //only remove if it's there
                if (iIndex != -1)
                {
                    g_lButtons = llDeleteSubList(g_lButtons, iIndex, iIndex);
                }
            }
        }
        else if (iNum == DIALOG_RESPONSE)
        {
            if (kID == g_kMenuID)
            {
                list lMenuParams = llParseStringKeepNulls(sStr, ["|"], []);
                key kAv = (key)llList2String(lMenuParams, 0);
                string sMessage = llList2String(lMenuParams, 1);
                integer iPage = (integer)llList2String(lMenuParams, 2);
                if (sMessage == UPMENU)
                {
                    llMessageLinked(LINK_SET,MENU_SUBMENU, g_sParentMenu, kAv);
                }
                else if (llListFindList(g_lButtons,[sMessage]) != -1)
                {
                    llMessageLinked(LINK_SET,MENU_SUBMENU, sMessage, kAv);
                }
            return;                
            }
        }
        else if (iNum >= COMMAND_OWNER && iNum <= COMMAND_WEARER)
        {
            list lParams = llParseStringKeepNulls(sStr, [" "], []);
            string sCommand = llToLower(llList2String(lParams, 0));
            string sValue = llToLower(llList2String(lParams, 1));
            if (sStr == "refreshmenu")
            {
                g_lButtons = [];
                llMessageLinked(LINK_SET, MENU_REQUEST, g_sSubMenu, NULL_KEY);
            }
            else if (sStr == llToLower(g_sSubMenu))
            {
                DoMenu(kID);
                g_iRemenu=FALSE;
            }
            return;
        }
        else if (iNum == ATTACHMENT_PING)
        {
            llOwnerSay("new attachment reset_channel");
            BridgeResponse(iSender,ATTACHMENT_CHANRESET,sStr,kID);
        }        
        else if (iNum == ATTACHMENT_FORWARD)
        {
//            list lParts = llParseStringKeepNulls(sStr, ["|"], []);
//            if ((integer)llList2String(lParts,0) == ATTACHMENT_PASSTHROUGH)
//            {
//                BridgePassthrough(sStr,kID);
//            }
            return;
        }
        if (!fromAttachment(iNum,sStr,kID))
        {        
            BridgeResponse(iSender,iNum,sStr,kID);
        }
    }

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
    
    timer()
    {
        integer max = llGetListLength(g_lAttMenu);
        if(max > 0)
        {
            integer i;
            list temp = [];
            for(i=0;i<max;i=i+3)
            {
               if (llGetObjectDetails(llList2Key(g_lAttMenu,i),[OBJECT_ATTACHED_POINT]) != [] )
               {
                   temp += llList2List(g_lAttMenu, i, i+2);
               }
               else
               {
                    llMessageLinked(LINK_SET, MENU_REMOVE, llList2String(g_lAttMenu,i+1) + "|" +  llList2String(g_lAttMenu,i+2), NULL_KEY);
                }
            }
            g_lAttMenu = temp;
        }
    }    
}