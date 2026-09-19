-- Headless regression checks; this does not emulate the live WoW renderer/API.
local objects={}
local methods={}
local mt={__index=function(_,key)
    if methods[key] then return methods[key] end
    if key:match('^[A-Z]') then return function() end end
end}
local function frame(parent)
    local f=setmetatable({parent=parent,scripts={},width=400,height=500,shown=true,enabled=true,text="",points={}},mt)
    objects[#objects+1]=f; return f
end
function methods:CreateFontString() return frame(self) end
function methods:CreateTexture() return frame(self) end
function methods:CreateLine() return frame(self) end
function methods:GetFont() return 'font',12,'' end
function methods:SetSize(w,h) self.width=w;self.height=h end
function methods:SetWidth(w) self.width=w end
function methods:SetHeight(h) self.height=h end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:GetEffectiveScale() return 1 end
function methods:GetFrameLevel() return 1 end
function methods:GetText() return self.text end
function methods:SetText(t) self.text=tostring(t or '') end
function methods:SetScript(k,v) self.scripts[k]=v end
function methods:HookScript(k,v) self.scripts[k]=v end
function methods:SetPoint(...) self.points[#self.points+1]={...} end
function methods:GetPoint() return 'CENTER',UIParent,'CENTER',0,0 end
function methods:ClearAllPoints() self.points={} end
function methods:GetParent() return self.parent end
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false end
function methods:SetShown(v) self.shown=v end
function methods:IsShown() return self.shown end
function methods:IsEnabled() return self.enabled end
function methods:Enable() self.enabled=true end
function methods:Disable() self.enabled=false end
function methods:SetChecked(v) self.checked=v end
function methods:GetChecked() return self.checked end
function methods:SetValue(v) self.value=v end
function methods:GetValue() return self.value or 0 end
function methods:GetMinMaxValues() return 0,100 end
function methods:GetName() return self.name end
function methods:GetLeft() return 0 end
function methods:IsMouseOver() return false end
function methods:GetCenter() return 500,400 end
function CreateFrame(_,name,parent) local f=frame(parent); f.name=name;if name then _G[name]=f end;return f end
UIParent=frame();UIParent:SetSize(1920,1080)
GameTooltip=frame();function GameTooltip_Hide() GameTooltip:Hide() end
SlashCmdList={};UISpecialFrames={};DEFAULT_CHAT_FRAME=frame()
C_Timer={After=function() end,NewTicker=function() end}
function GetLocale() return 'enUS' end
function GetCurrentRegion() return 3 end
function GetRealmName() return 'TestRealm' end
function GetNormalizedRealmName() return 'TestRealm' end
function time() return 10000 end
function GetTime() return 100 end
function date(fmt,t) return os.date(fmt,t) end
function wipe(t) for k in pairs(t) do t[k]=nil end end
function IsShiftKeyDown() return false end
function GetItemInfo() return nil end
function GetItemInfoInstant() return nil end
function GetBuildInfo() return '12',1,'date',120100 end
WOW_PROJECT_MAINLINE=1;WOW_PROJECT_ID=1
local base='DealScryer/'
assert(loadfile(base..'Core.lua'))('DealScryer')
local FS=DealScryer; FS.DB={};FS.DeepDefaults(FS.DEFAULTS,FS.DB)
for _,file in ipairs({'Locale.lua','Undermine.lua','Scanner.lua','UI.lua','Experience.lua'}) do dofile(base..file) end
local UI,S=FS.UI,FS.Scanner
local market=FS:GetMarketState()
local function record(id,profit,risk)
 return {itemID=id,name='Test '..id,buy=10000,safeSell=20000,profit=profit,roi=1,discount=0.5,score=70,suspiciousMarket=risk,historyCount=2,distinctPrices=3,risk='low',source='local',totalQty=10}
end
local safe=record(1,9000,false);local suspect=record(2,999999999,true)
S.results={suspect,safe};S.lastAnalysis={[1]=safe,[2]=suspect}
FS.DB.settings.sort='profit'
assert(S:GetVisibleList('results','')[1]==safe,'Suspicious profit must never lead')
FS.DB.settings.sortDesc=false
assert(S:GetVisibleList('results','')[1]==safe)
FS.DB.searchOptions.riskMode='only';assert(#S:GetVisibleList('results','')==1 and S:GetVisibleList('results','')[1]==suspect)
FS.DB.searchOptions.riskMode='hide';assert(S:GetVisibleList('results','')[1]==safe)
FS:ApplyProfile({maxPriceGold=0.5});assert(#S:GetVisibleList('results','')==0)
FS:ApplyProfile({minROIPct=150});assert(#S:GetVisibleList('results','')==0)
FS:ApplyProfile({});assert(#S:GetVisibleList('results','')==2)
local notices=0;FS.Print=function() notices=notices+1 end
FS.DB.settings.alertScore=80;FS.DB.watchlist['1']={targetGold=1}
S:FireAlerts();assert(notices==1);S:FireAlerts();assert(notices==1,'Do not repeat unchanged watch alert')
safe.buy=20000;S:FireAlerts();safe.buy=10000;S:FireAlerts();assert(notices==2,'Rearm after threshold exit')
FS.DB.watchlist['2']={targetGold=100};S:FireAlerts();assert(notices==2,'Do not alert on suspicious target')
assert(FS:AddJournalTrade('Test',2,100,150,10));assert(FS:JournalProfit(market.journal[1])==400000)
assert(FS:AddJournalTrade('Loss',1,100,50,5));assert(FS:JournalProfit(market.journal[2])==-550000)
assert(not FS:AddJournalTrade('Invalid',1,-1,50,0));assert(not FS:AddJournalTrade('Invalid',1.5,1,2,0))
assert(not FS:AddJournalTrade('Invalid',1,1,'',0));assert(not FS:AddJournalTrade('Invalid',1,math.huge,2,0))
assert(#market.journal==2)
assert(FS:ExplainDeal(suspect):find('unreliable estimates',1,true))
S.currentSnapshotAt=9000;assert(FS:GetDataAge():find('16m'))
UI:Create(); UI.selected=safe; UI:RefreshDetail(); UI:Layout()
assert(#UI.oeGraph.empty.points==2,'Empty text must be bounded on both sides')
UI:ShowProfiles();UI:ShowWatchTarget();UI:ShowJournal();UI:ShowExplanation()
local f=UI.journalWindow
local function click(label,parent)
 for _,b in ipairs(objects) do
  if b.parent==parent and b.label and b.label.text==label then b.scripts.OnClick(b);return end
 end
 error('Missing button '..label)
end
click('Undo last',f);click('Undo last',f);assert(#market.journal==0)
click('Restore',f);click('Restore',f);assert(#market.journal==2)
f.fields.item:SetText('New trade');f.fields.qty:SetText('3');f.fields.cost:SetText('10');f.fields.proceeds:SetText('20');f.fields.fees:SetText('1')
click('Record trade',f);assert(#market.journal==3 and FS:JournalProfit(market.journal[3])==90000)
click('Record trade',f);assert(#market.journal==3,'Cleared totals must prevent accidental duplicate entry')
UI.profileWindow.name:SetText('Custom');click('Save',UI.profileWindow);assert(FS.DB.profiles.Custom)
UI.watchWindow.price:SetText('2.5');click('Save target',UI.watchWindow);assert(FS.DB.watchlist['1'].targetGold==2.5)
FS.DB.settings.advancedColumns=false;UI:Layout();assert(UI.headerButtons.sell.shown==false)
FS.DB.settings.advancedColumns=true;UI:Layout();assert(UI.headerButtons.sell.shown==true)
market.history['1']={samples={{t=100,ref=12000},{t=200,ref=14000}}};UI.selected=safe;UI:DrawPriceHistory();assert(#UI.priceGraph.historySamples==2)
UI.selected=nil;UI:DrawPriceHistory();assert(UI.priceGraph.historySamples==nil,'Selection clear must remove stale hover data')
print('PASS: filters, suspicious ranking, profiles, watch alert rearming/deduplication, journal validation/profit/undo, UI construction and controls, compact columns, graph state')
