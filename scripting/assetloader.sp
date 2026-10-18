#include <sdktools>
#include <regex>
#include <ripext>

#pragma semicolon 1
#pragma newdecls required

#define MAX_LOG_LINE 512

public Plugin myinfo = 
{
	name = "[ANY] Asset Loader",
	author = "Bradasparky, Heapons",
	description = "Automatically precaches and downloads assets via json config",
	version = "1.1.0",
	url = "https://github.com/Bradasparky/sm-asset-loader"
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
ArrayList g_hLogLines;

public void OnPluginStart()
{
    g_hLogLines = new ArrayList(ByteCountToCells(MAX_LOG_LINE));
    g_iTable = FindStringTable("downloadables");
    if (g_iTable == INVALID_STRING_TABLE)
        SetFailState("The 'downloadables' table does not exist.");
    
    g_hExts = new StringMap();
    g_hExts.SetValue("wav", Precache_Sound);
    g_hExts.SetValue("mp3", Precache_Sound);
    g_hExts.SetValue("vmt", Precache_Model);
    g_hExts.SetValue("mdl", Precache_Model);

    g_cvLog = CreateConVar("sm_assetloader_log", "0", "Toggle asset logging.", _, true, 0.0, true, 1.0);
    RegAdminCmd("sm_reload_assets", Command_ParseAssets, ADMFLAG_ROOT, "Reload the asset config.");
}

Action Command_ParseAssets(int iClient, int iArgs)
{
    ParseAssets();
    ReplyToCommand(iClient, "[SM] Successfully loaded assets!");
    
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
    
    bool bLog = g_cvLog.BoolValue;
    char sMapName[PLATFORM_MAX_PATH], sMapDisplayName[64];
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
                LogLine(" \
                     + = Added to downloads and/or precached\n \
                     - = No precache method, added to downloads\n \
                     ! = Missing file or no regex matches\n \
                     X = Bad regex\n\
                    (N) = Number of matching files\n");

                ProcessAssets(hMapEntry, "precache", bLog);
                ProcessAssets(hMapEntry, "download", bLog);
                delete hMapEntry;
            }
        }
        
        delete hRegex;
    }
    
    delete hKeys;
    delete hMaps;
    delete hJson;

    if (!bLog)
        return;
    
    BuildPath(Path_SM, sPath, sizeof(sPath), "logs/assetloader.log");
    File hFile = OpenFile(sPath, "w");
    if (hFile == null)
    {
        LogError("Failed to create or open log file at 'logs/assetloader.log'");
        return;
    }
    
    char sLog[MAX_LOG_LINE];
    int iLength = g_hLogLines.Length;
    for (int i; i < iLength; i++)
    {
        g_hLogLines.GetString(i, sLog, sizeof(sLog));
        hFile.WriteLine(sLog);
    }

    hFile.Flush();
    delete hFile;

    LogMessage("Successfully logged assets to 'logs/assetloader.log'");
}

void ProcessAssets(JSONObject hMapEntry, const char[] sType, bool bLog)
{
    JSONArray hAssets = view_as<JSONArray>(hMapEntry.Get(sType));
    if (hAssets == null)
        return;
    
    bool bDownload = strcmp(sType, "download") == 0;
    
    int iAssets = hAssets.Length;
    if (iAssets == 0)
    {
        delete hAssets;
        return;
    }
    
    if (bLog)
    {
        if (bDownload)
            LogLine("Download List:\n");
        else
            LogLine("Precache List:\n");
    }
    
    if (bDownload)
        g_bLock = LockStringTables(false);
    
    char sEntry[PLATFORM_MAX_PATH];
    ArrayList hRegexFiles = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
    for (int i; i < iAssets; i++)
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
                    LogLine(" - %s", sEntry);
                continue;
            }
            
            ProcessFile(sEntry, bDownload, bLog);
            continue;
        }
        
        // Regex entry: split at the last '/' and scan that directory.
        Regex hRegex = new Regex(sEntry);
        if (hRegex == null)
        {
            LogLine(" X %s", sEntry);
            continue;
        }
        
        if (FileExists(sEntry))
        {
            ProcessFile(sEntry, bDownload, bLog);
            continue;
        }
        
        char sDir[PLATFORM_MAX_PATH];
        strcopy(sDir, iSlash + 2, sEntry);
        
        DirectoryListing hDir = OpenDirectory(sDir, true);
        if (hDir != null)
        {
            hRegexFiles.Clear();
            FileType eType;
            char sFileName[PLATFORM_MAX_PATH], sFullPath[PLATFORM_MAX_PATH];
            while (hDir.GetNext(sFileName, sizeof(sFileName), eType))
            {
                if (eType != FileType_File)
                    continue;
                
                Format(sFullPath, sizeof(sFullPath), "%s%s", sDir, sFileName);
                if (hRegex.Match(sFullPath) > 0)
                    ProcessFile(sFullPath, bDownload, bLog, hRegexFiles);
            }
            
            delete hDir;

            if (bLog)
            {
                char sLog[MAX_LOG_LINE];
                int iFiles = hRegexFiles.Length;
                if (iFiles == 0)
                    LogLine(" ! %s", sEntry);
                else
                {
                    LogLine("(%i) %s", hRegexFiles.Length, sEntry);
                    for (int o; o < iFiles; o++)
                    {
                        hRegexFiles.GetString(o, sLog, sizeof(sLog));
                        LogLine(sLog);
                    }
                }
            }
        }
        
        delete hRegex;
    }

    delete hRegexFiles;
    
    if (bDownload)
        LockStringTables(g_bLock);
    else if (bLog)
        LogLine(" ");
    
    delete hAssets;
}

void ProcessFile(const char[] sFile, bool bDownload, bool bLog, ArrayList hRegexFiles = null)
{
    if (bDownload)
        AddToStringTable(g_iTable, sFile);
    
    int iPrecache, iExt = StrContains(sFile, ".");
    if (iExt == -1 || !g_hExts.GetValue(sFile[iExt + 1], iPrecache))
    {
        if (bLog)
        {
            char sLog[MAX_LOG_LINE];
            FormatEx(sLog, sizeof(sLog), "%s - %s", hRegexFiles ? "  " : "", sFile);
            if (hRegexFiles)
                hRegexFiles.PushString(sLog);
            else
                LogLine(sLog);
        }
        return;
    }
    
    switch (iPrecache)
    {
        case Precache_Model: PrecacheModel(sFile);
        case Precache_Sound: PrecacheSound(sFile);
    }
    
    if (bLog)
    {
        char sLog[MAX_LOG_LINE];
        FormatEx(sLog, sizeof(sLog), "%s + %s", hRegexFiles ? "  " : "", sFile);
        if (hRegexFiles)
            hRegexFiles.PushString(sLog);
        else
            LogLine(sLog);
    }
}

void LogLine(const char[] sFormat, any ...)
{
    char sLog[MAX_LOG_LINE];
    VFormat(sLog, sizeof(sLog), sFormat, 2);
    g_hLogLines.PushString(sLog);
}
