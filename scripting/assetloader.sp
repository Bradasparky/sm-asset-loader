#include <sdktools>
#include <regex>
#include <ripext/json>

#pragma semicolon 1
#pragma newdecls required
#pragma dynamic 32768

public Plugin myinfo = 
{
	name = "[ANY] Asset Loader",
	author = "Bradasparky, Heapons",
	description = "Automatically precaches and downloads assets via json config",
	version = "1.1.0",
	url = "https://github.com/Heapons/sm-asset-loader"
};

enum
{
    Precache_Model,
    Precache_Sound
}

int g_iTable;
bool g_bLock;
ConVar g_cvLog;
StringMap g_hExts;

public void OnPluginStart()
{
    g_iTable = FindStringTable("downloadables");
    if (g_iTable == INVALID_STRING_TABLE)
        SetFailState("The 'downloadables' table does not exist.");
    
    g_hExts = new StringMap();
    g_hExts.SetValue("wav", Precache_Sound);
    g_hExts.SetValue("mp3", Precache_Sound);
    g_hExts.SetValue("vmt", Precache_Model);
    g_hExts.SetValue("mdl", Precache_Model);

    g_cvLog = CreateConVar("sm_assetloader_log", "0", "Toggle precached asset logging.", _, true, 0.0, true, 1.0);
    RegAdminCmd("sm_reload_assets", Command_ParseAssets, ADMFLAG_ROOT, "Reload the asset config.");
}

Action Command_ParseAssets(int iClient, int iArgs)
{
    ParseAssets();
    ReplyToCommand(iClient, "[SM] Parsed assets successfully!");
    return Plugin_Handled;
}

public void OnMapStart()
{
    ParseAssets();   
}

void ParseAssets()
{
    char sPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, sPath, sizeof(sPath), "configs/assetloader.json");
    
    JSONObject hJson = JSONObject.FromFile(sPath);
    if (hJson == null)
        SetFailState("Failed to read from %s", sPath);
    
    JSONObject hMaps = view_as<JSONObject>(hJson.Get("maps"));
    if (hMaps == null)
    {
        delete hJson;
        SetFailState("Could not find 'maps' object in %s", sPath);
    }
    
    char sMapName[96], sMapDisplayName[64];
    GetCurrentMap(sMapName, sizeof(sMapName));
    GetMapDisplayName(sMapName, sMapDisplayName, sizeof(sMapDisplayName));
    
    JSONObjectKeys hKeys = hMaps.Keys();
    char sKey[128];
    
    while (hKeys.ReadKey(sKey, sizeof(sKey)))
    {
        Regex hRegex = new Regex(sKey);
        if (hRegex == null)
        {
            delete hRegex;
            continue;
        }
        
        if (hRegex.Match(sMapDisplayName) > 0)
        {
            JSONObject hMapEntry = view_as<JSONObject>(hMaps.Get(sKey));
            if (hMapEntry != null)
            {
                ProcessAssets(hMapEntry, "precache");
                ProcessAssets(hMapEntry, "download");
                delete hMapEntry;
            }
        }
        
        delete hRegex;
    }
    
    delete hKeys;
    delete hMaps;
    delete hJson;
}

void ProcessAssets(JSONObject hMapEntry, const char[] sType)
{
    JSONArray hAssets = view_as<JSONArray>(hMapEntry.Get(sType));
    if (hAssets == null)
        return;
    
    bool bDownload = strcmp(sType, "download") == 0;
    bool bLog = g_cvLog.BoolValue;
    
    int iLength = hAssets.Length;
    if (iLength == 0)
    {
        delete hAssets;
        return;
    }
    
    if (bLog)
    {
        if (bDownload)
            PrintToServer("Download List:\n + = Precached & Added to Downloads\n - = No Precache Method, Added to Downloads \n ! = Missing\n- - - - - - - - - - - -");
        else
            PrintToServer("Precache List:\n + = Precached\n - = No Precache Method\n ! = Missing\n- - - - - - - - - - - -");
    }
    
    if (bDownload)
        g_bLock = LockStringTables(false);
    
    char sEntry[PLATFORM_MAX_PATH];
    for (int i; i < iLength; i++)
    {
        if (hAssets.GetType(i) != JSON_STRING)
            continue;
        
        hAssets.GetString(i, sEntry, sizeof(sEntry));
        
        int iSlash = FindCharInString(sEntry, '/', true);
        if (iSlash == -1)
        {
            // No directory component: treat as a literal file (Valve FS).
            if (!FileExists(sEntry, true))
            {
                if (bLog)
                    PrintToServer(" ! %s", sEntry);
                continue;
            }
            
            ProcessFile(sEntry, bDownload, bLog);
            continue;
        }
        
        // Regex entry: split at the last '/' and scan that directory.
        Regex hRegex = new Regex(sEntry);
        if (hRegex == null)
            continue;
        
        char sDir[PLATFORM_MAX_PATH];
        strcopy(sDir, iSlash + 2, sEntry);
        
        DirectoryListing hDir = OpenDirectory(sDir, true);
        if (hDir != null)
        {
            char sFileName[PLATFORM_MAX_PATH], sFullPath[PLATFORM_MAX_PATH];
            FileType eType;
            while (hDir.GetNext(sFileName, sizeof(sFileName), eType))
            {
                if (eType != FileType_File)
                    continue;
                
                Format(sFullPath, sizeof(sFullPath), "%s%s", sDir, sFileName);
                if (hRegex.Match(sFullPath) > 0)
                    ProcessFile(sFullPath, bDownload, bLog);
            }
            delete hDir;
        }
        
        delete hRegex;
    }
    
    if (bDownload)
        LockStringTables(g_bLock);
    else if (bLog)
        PrintToServer(" ");
    
    delete hAssets;
}

void ProcessFile(const char[] sFile, bool bDownload, bool bLog)
{
    if (bDownload)
        AddToStringTable(g_iTable, sFile);
    
    int iPrecache, iExt = StrContains(sFile, ".");
    if (iExt == -1 || !g_hExts.GetValue(sFile[iExt + 1], iPrecache))
    {
        if (bLog)
            PrintToServer(" - %s", sFile);
        return;
    }
    
    switch (iPrecache)
    {
        case Precache_Model: PrecacheModel(sFile);
        case Precache_Sound: PrecacheSound(sFile);
    }
    
    if (bLog)
        PrintToServer(" + %s", sFile);
}
