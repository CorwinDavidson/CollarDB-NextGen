/*--------------------------------------------------------------------------------**
**  File: CDB - template                                                          **
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



/*-------------//
//  FUNCTIONS  //
//-------------*/



/*---------------//
//  HANDLERS     //
//---------------*/
// pragma inline
HandleSETTINGS(integer iSender, integer iNum, string sStr, key kID)
{
}

// pragma inline
HandleDIALOG(integer iSender, integer iNum, string sStr, key kID)
{
}

// pragma inline
HandleMENU(integer iSender, integer iNum, string sStr, key kID)
{
}

// pragma inline
HandleCHATCOMMAND(integer iSender, integer iNum, string sStr, key kID)
{
  
    if (iNum == REGISTER_CHAT_COMMAND)
    {
     //   MenuResponse();
    }
    else if (iNum == DELETE_CHAT_COMMAND)
    {
        
    }
    else if (iNum == CHAT_COMMAND)
    {
        
    }
}

// pragma inline
HandleCOMMAND(integer iSender, integer iNum, string sStr, key kID)
{
}
// pragma inline
HandleAPPEARANCE(integer iSender, integer iNum, string sStr, key kID)
{
}

/*---------------//
//  MAIN CODE    //
//---------------*/
default {
    state_entry() {

    }
    
    attach(key kID)
    {
        if (kID == NULL_KEY)
        {

        }
    }
        
    on_rez(integer start)
    {
    
    }
    
    link_message(integer iSender, integer iNum, string sStr, key kID)
    {
        if ((iNum >= SETTING_SAVE) && (iNum <= SETTING_REQUEST_NOCACHE))
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
        else if ((iNum >= REGISTER_CHAT_COMMAND) && (iNum <= CHAT_COMMAND))
        {
            HandleCHATCOMMAND(iSender,iNum,sStr,kID);
        } 
    } 
    
    run_time_permissions(integer nParam)
    {
        if( nParam & PERMISSION_TAKE_CONTROLS)
        {
        }
    }
        
    changed(integer iChange)
    {
        if (iChange & CHANGED_TELEPORT)
        {

        }

        if (iChange & CHANGED_INVENTORY)
        {

        }
    }
}
