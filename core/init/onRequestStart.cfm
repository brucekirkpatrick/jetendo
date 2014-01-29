<cfoutput>

<cffunction name="onCodeDeploy" localmode="modern" access="public" returntype="any">
	<cfscript>
	// recreate CFCs if they date doesn't match
	application.zcore.functions.zClearCFMLTemplateCache();
	codeDeployCom=createobject("component", "zcorerootmapping.com.zos.codeDeploy");
	codeDeployCom.onCodeDeploy();
	</cfscript>
</cffunction>

<cffunction name="onExecuteCacheReset" localmode="modern" access="public">
	<cfscript>
	setting requesttimeout="3000";
	ts={
		success:true,
		reset:application.zcore.functions.zso(form, 'reset')
	};
	request.zos.zreset=ts.reset;
	
	// make sure file permissions are updated
	if(fileexists(request.zos.globals.privatehomedir&'__zdeploy-complete.txt')){
		while(true){
			sleep(100);
			if((gettickcount()-start)/1000 GT 30){
				break;
			}
			if(not fileexists(request.zos.globals.privatehomedir&'__zdeploy-complete.txt')){
				break;
			}
		}
	}
	
	if(request.zos.zreset EQ "code" or request.zos.zreset EQ "app" or request.zos.zreset EQ "site" or request.zos.zreset EQ "all"){
		variables.onCodeDeploy(); 
	}
	if(request.zos.zreset EQ "app" or request.zos.zreset EQ "all"){
		variables.onApplicationStart();
	}
	if(request.zos.zreset EQ "site" or request.zos.zreset EQ "all"){
		local.temp34=structnew();
		local.temp34.site_id=request.zos.globals.id;
		local.temp34.globals=application.zcore.siteGlobals[request.zos.globals.id];//request.zos.globals;  
		local.temp34=application.zcore.functions.zGetSite(local.temp34);
		application.sitestruct[request.zos.globals.id]=local.temp34; 
	} 
	if(request.zos.zreset EQ "all" or request.zos.zreset EQ "site" or request.zos.zreset EQ "app"){
		lock name="#request.zos.zcoreRootPath#-compilePackage" type="exclusive" timeout="30" throwontimeout="yes"{
			application.zcore.skin.compilePackage();
		}
	}
	if(request.zos.zreset EQ "cache"){
		application.zcore.functions.zOS_rebuildCache(); 
	}
	if(request.zos.zreset EQ "session" or request.zos.zreset EQ "all"){
		application.zcore.user.logOut();
		structclear(session);
	}
	
	application.zcore.functions.zReturnJson(ts);
	</cfscript>
</cffunction>

<cffunction name="OnRequestStart" localmode="modern" access="public" returntype="any" output="true" hint="Fires at first part of page processing.">
  <cfargument name="TargetPage" type="string" required="true" /><cfscript>   
	s=gettickcount('nano'); 
	 
	ts=structnew();
	ts.name="zSessionExpireDate";
	ts.value=getHttpTimeString(now()+this.sessiontimeout);
	ts.expires=this.sessiontimeout;
	application.zcore.functions.zCookie(ts); 
	 
	savecontent variable="local.output"{
		arrayappend(request.zos.arrRunTime, {time:gettickcount('nano'), name:'Application.cfc onRequestStart begin'});
		if(structkeyexists(application, 'zDeployExclusiveLock') and ((request.zos.isDeveloper EQ false and request.zos.isServer EQ false) or not structkeyexists(form, 'zreset') or form.zreset EQ "")){	
			setting requesttimeout="350";
			lock type="exclusive" timeout="300" throwontimeout="no" name="#request.zos.installPath#-zDeployExclusiveLock"{};
		}
		if(structkeyexists(application,'sessionstruct') and structkeyexists(application.sessionstruct, session.sessionid)){
			request.zos.oldestPossibleSessionDate=now()-this.sessiontimeout;
			request.zos.oldestPossibleSessionDate=createodbcdatetime(dateformat(request.zos.oldestPossibleSessionDate,"yyyy-mm-dd")&" "&timeformat(request.zos.oldestPossibleSessionDate, "HH:mm:ss"));
			if(datecompare(application.sessionstruct[session.sessionid].lastvisit, request.zos.oldestPossibleSessionDate) LTE 0){
				structdelete(application.sessionstruct, session.sessionid);
			}else{
				structappend(session, application.sessionStruct[session.sessionid], true);
				structdelete(application.sessionStruct,session.sessionid);
				//writeoutput('copied session<br />');
				
			}
		}
		
		request.zos.inServerManager=false;
		
		if(left(request.zos.originalURL, len("/z/server-manager/")) EQ "/z/server-manager/" or left(request.zos.originalURL, len("/z/_com/zos/app")) EQ "/z/_com/zos/app"){
			request.zos.inServerManager=true;
		}
		
		//local.s=gettickcount('nano');
		Request.zOSBeginFile=ArrayNew(1);
		Request.zOSEndFile=ArrayNew(1);
		request.zos.whiteSpaceEnabled=false;
		
		
		ts=structnew();
		ts.name="zLoggedIn";
		if(isDefined('session.zos.user')){
			request.zos.userSession=duplicate(session.zos.user);
			ts.value="1";
		}else{
			request.zos.userSession={groupAccess:{}};
			ts.value="0";
		}
		ts.expires=this.sessiontimeout;
		application.zcore.functions.zCookie(ts); 
	 
		if(structkeyexists(form,request.zos.urlRoutingParameter) EQ false){	
			return;	
		}
		request.zos.migrationMode=false;
		if(request.zos.isDeveloper or request.zos.istestserver){
			if(isDefined('session.zos.verifyQueries') EQ false and request.zos.istestserver){
				session.zos.verifyQueries=true;
			}
			if(structkeyexists(form,'zDisableSystemCaching')){
				if(form.zDisableSystemCaching){
					session.zDisableSystemCaching=true;
					request.zos.disableSystemCaching=true;
				}else{
					structdelete(session,'zDisableSystemCaching');
				}
			}
			if(isDefined('session.zDisableSystemCaching')){
				request.zos.disableSystemCaching=true;
			}else{
				request.zos.disableSystemCaching=false;
			}
		}else{
			if(request.zos.isServer EQ false){
				request.zos.zreset="";
			}
			request.zos.disableSystemCaching=false;
		}
		if(request.zos.disableSystemCaching or not structkeyexists(application,'zcore') or not structkeyexists(application.zcore,'functions') or (request.zos.zreset EQ "app" or request.zos.zreset EQ "all")){
			variables.onApplicationStart();
		}
		if(request.zos.allowRequestCFC){
			request.zos.functions=application.zcore.functions;
		}
		//writeoutput(((gettickcount('nano')-local.s)/1000000000)&' seconds0restore session<br />');	local.s=gettickcount('nano');
		 
		local.timeSpan=CreateTimeSpan( 0,0,30,0);
		if(structkeyexists(session, 'cfid') and structkeyexists(session, 'cftoken')){
			try{
				application.zcore.functions.zCookie({name:'cfid', value=session.cfid, expires: local.timeSpan });
				application.zcore.functions.zCookie({name:'cftoken', value=session.cftoken, expires:local.timeSpan });
				//application.zcore.functions.zCookie({name:'jsessionid', value=session.sessionid, expires:local.timeSpan });
			}catch(Any e){
				// ignore session cookie errors.
			}
		}
		local.temphomedir=Request.zOSHomeDir;//replace(expandpath('/'),"\","/","all");
		local.tempdomain="http://"&lcase(request.zos.cgi.server_name);
		local.tempsecuredomain="https://"&lcase(request.zos.cgi.server_name); // need to be able to override this.

		request.zos.originalFormScope=duplicate(form);
		for(local.i in form){
			if(isSimpleValue(form[local.i])){
				form[local.i]=replace(replace(form[local.i], local.tempdomain, '', 'all'), local.tempsecuredomain, '', 'all');
			}
		} 
		if(structkeyexists(application.zcore.sitePaths, local.temphomedir)){
			local.site_id=application.zcore.sitePaths[local.temphomedir];
		}else if(structkeyexists(application.zcore.sitePaths, local.tempdomain)){
			local.site_id=application.zcore.sitePaths[local.tempdomain];
		}else if(structkeyexists(application.zcore.sitePaths, local.tempsecuredomain)){
			local.site_id=application.zcore.sitePaths[local.tempsecuredomain];
		}else{
			application.zcore.functions.zCheckDomainRedirect(); 
		}
		if(request.zos.allowRequestCFC){
			structappend(request.zos, application.zcore.componentObjectCache, true);
		}
		
		if(request.zos.disableSystemCaching or structkeyexists(application,'sitestruct') EQ false or structkeyexists(application.sitestruct, local.site_id) EQ false or  not structkeyexists(application.sitestruct[local.site_id], 'getSiteRan') or (request.zos.zreset EQ "site" or request.zos.zreset EQ "all")){
			local.temp34=structnew();
			local.temp34.site_id=local.site_id;
			local.temp34.globals=application.zcore.siteGlobals[local.site_id];//request.zos.globals;  
			local.temp34=application.zcore.functions.zGetSite(local.temp34);
			application.sitestruct[local.site_id]=local.temp34; 
		} 
		if(request.zos.allowRequestCFC){
			request.app=application.sitestruct[local.site_id];
		} 
		request.zos.globals=application.sitestruct[local.site_id].globals; 
		
		
		if(replace(replace(request.zos.globals.domain, "https://", ""),"http://", "") NEQ request.zos.cgi.http_host){
			application.zcore.functions.zCheckDomainRedirect(); 
		}
		request.zos.site_id=local.site_id;
		//structappend(request.zos.globals, application.zcore.serverGlobals, false);
		if(request.zos.isdeveloper and isDefined('session.zos.verifyQueries') and session.zos.verifyQueries){
			local.verifyQueriesEnabled=true;
		}else{
			local.verifyQueriesEnabled=false;
		}
		if(isDefined('session.zos.user')){
			request.zos.db=application.sitestruct[request.zos.globals.id].dbComponents.cacheDisabledDB;
			request.zos.dbNoVerify=application.sitestruct[request.zos.globals.id].dbComponents.cacheDisabledNoVerifyDB;
		}else{
			request.zos.db=application.sitestruct[request.zos.globals.id].dbComponents.cacheEnabledDB;
			request.zos.dbNoVerify=application.sitestruct[request.zos.globals.id].dbComponents.cacheEnabledNoVerifyDB;
		}
		
		request.zos.queryObject=application.zcore.db.newQuery();
		request.zos.noVerifyQueryObject=request.zos.dbNoVerify.newQuery();
		
		if(structkeyexists(form,'form_last_name') and len(form.form_last_name)){
			writeoutput('.<!-- stop spamming -->'); 
			application.zcore.functions.zabort();
		}
		if(structkeyexists(form,'zosdomainvalidation')){
			writeoutput('OK');
			application.zcore.functions.zabort();
		}
		variables.nowDate=request.zOS.mysqlnow;
		request.zos.onrequestcompleted=false;
		
		if(request.zos.allowRequestCFC){
			StructAppend(variables, request.zos.functions);
		}
		
		
		
		if(request.zos.isDeveloper){
			if(structkeyexists(form, 'zOSDebuggerLastOutput')){
				form.znotemplate=1;
				if(isDefined('session.zos.zOSDebuggerLastOutput')){
					writeoutput(session.zos.zOSDebuggerLastOutput);
				}else{
					writeoutput('No debugging output available');
				}
				application.zcore.functions.zabort();
			}
		}else{
			request.zos.zreset="";
			form.zdebugurl=false;
		}
		//writeoutput(((gettickcount('nano')-local.s)/1000000000)&' seconds0simple stuff<br />');	local.s=gettickcount('nano');
		//writeoutput(((gettickcount('nano')-local.s)/1000000000)&' seconds0<br />');	local.s=gettickcount('nano');
		variables.onRequestStart1();
		//writeoutput(((gettickcount('nano')-local.s)/1000000000)&' seconds1<br />');	local.s=gettickcount('nano');
		variables.onRequestStart12();
		//writeoutput(((gettickcount('nano')-local.s)/1000000000)&' seconds12<br />');	local.s=gettickcount('nano');
		variables.onRequestStart2();
		//writeoutput(((gettickcount('nano')-local.s)/1000000000)&' seconds2<br />');	local.s=gettickcount('nano');
		variables.onRequestStart3();
		//writeoutput(((gettickcount('nano')-local.s)/1000000000)&' seconds3<br />');	local.s=gettickcount('nano');
		variables.onRequestStart4();
		arrayappend(request.zos.arrRunTime, {time:gettickcount('nano'), name:'Application.cfc onRequestStart end'});
		//writeoutput(((gettickcount('nano')-local.s)/1000000000)&' seconds4<br />');	local.s=gettickcount('nano');
	}
	if(request.zos.isDeveloper and structkeyexists(form, 'displayRunTime')){
		if(isDefined('request.zos.arrRunTime')){
			writeoutput('<h2>Script Run Time Measurements</h2>');
			arrayprepend(request.zos.arrRunTime, {time:request.zos.startTime, name:'Application.cfc onCoreRequest Start'});
			for(i=2;i LTE arraylen(request.zos.arrRunTime);i++){
				writeoutput(((request.zos.arrRunTime[i].time-request.zos.arrRunTime[i-1].time)/1000000000)&' seconds | '&request.zos.arrRunTime[i].name&'<br />');	
			}
		}
		abort; 
	} 
	//writeoutput(trim(local.output));
	request.zos.onRequestOutput="";
	request.zos.onRequestStartOutput=local.output;
	</cfscript>
</cffunction>

<cffunction name="onRequestStart1" localmode="modern" output="yes"><cfscript>
	if(isDefined('session.zos') EQ false or (request.zos.zreset EQ "session" or request.zos.zreset EQ "all")){
		application.zcore.user.logOut();
		structclear(session);
	}
	variables.site_id=application.sitestruct[request.zos.globals.id].site_id; 
	
	request.zos.deployResetEnabled=false;
	
	if(structkeyexists(application.zcore.searchFormCache, request.zos.globals.id) EQ false){
		application.zcore.searchFormCache[request.zos.globals.id]=structnew();
	}
	if(request.zos.zreset EQ "cache"){
		setting requesttimeout="3000";
		application.zcore.functions.zOS_rebuildCache();
		application.zcore.functions.zredirect("/");
	}
	
	Request.zOS.debuggerEnabled = true;
	request.zos.templateData=structnew();
	application.zcore.template.init2();
	request.zos.memberImagePath="/zupload/member/";
	
	// apply the default theme
	themeName=application.zcore.functions.zso(request.zos.globals, 'themeName', false, "custom");
	if(themeName EQ ""){
		themeName="custom";
	}
	if(structkeyexists(session, 'zCurrentTheme')){
		themeName=session.zCurrentTheme;
	}  
	if(themeName NEQ "custom"){	
		if(themeName CONTAINS "/" or themeName CONTAINS "\" or themeName CONTAINS "."){
			throw("Invalid theme name.  Cannot contain forward or backward slashes or period as these are reserved by the system.");
		}
		request.zos.themePath="/jetendo-themes/"&themeName&"/";
		request.zos.themeCFCPath="/jetendo-themes."&themeName&".";
		
		if(not application.sitestruct[request.zos.globals.id].hasTemplates){
			application.zcore.template.setTemplate(request.zos.themeCFCPath&"templates.default");
		}
	}else{
		request.zos.themePath="";
		request.zos.themeCFCPath="";
	}
	application.zcore.cache.init();
	
	if(structkeyexists(application.zcore,'resetApplicationTrackerStruct') and structkeyexists(application.zcore.resetApplicationTrackerStruct, variables.site_id)){
		structdelete(application.zcore.resetApplicationTrackerStruct, variables.site_id);
		local.temp34=structnew();
		local.temp34.site_id=variables.site_id;
		local.temp34.globals=request.zos.globals;
		local.temp34=application.zcore.functions.zGetSite(local.temp34);
		application.sitestruct[variables.site_id]=local.temp34;
		application.sitestruct[request.zos.globals.id]=application.sitestruct[variables.site_id];
	}
	
	
	request.zos.msieCheck = FindNoCase("msie", CGI.HTTP_USER_AGENT);
	if (request.zos.msieCheck){
	   request.zos.msieVersNum = Val(RemoveChars(CGI.HTTP_USER_AGENT, 1, request.zos.msieCheck + 4));
	   if (request.zos.msieVersNum LTE 6){
			application.zcore.template.disableDate();
		}
	}
	if(request.zos.cgi.SERVER_PORT NEQ "443"){
		if(1 EQ 1 or request.zos.istestserver or (structkeyexists(request.zos.globals,'multidomainenabled') and request.zos.globals.multidomainenabled EQ 0)){
			request.zos.staticFileDomain="";
		}else{
			request.zos.staticFileDomain="http://"&request.zos.globals.shortdomain&".flre.us";
		}
	}else{
		request.zos.staticFileDomain="";	
	}
	if(request.zos.isServer or request.zos.isDeveloper or request.zos.istestserver){
		if(structkeyexists(form,'znotemplate')){
			request.zOS.templateData.notemplate=true;
			request.znotemplate=true;
		}
		if(structkeyexists(form, 'zregeneratemodelcache')){
			local.tempCom=createobject("component","zcorerootmapping.com.model.base");
			local.tempCom._generateModels(application.sitestruct[request.zos.globals.id]);
			/*
			application.zcore.tracking.showTimer("Model cache regenerated");
			application.zcore.functions.zabort();
			*/
			structdelete(form,'zregeneratemodelcache');
		}
	}else{
		request.znotemplate=false;
	}
	
	
	request.zos.page=structnew();
	request.zos.page.setActions=application.zcore.functions.legacySetActions;
	request.zos.page.setDefaultAction=application.zcore.functions.legacySetDefaultAction;
	application.zcore.user.customSet = false;
	application.zcore.user.customStruct = StructNew();
	
	
	</cfscript>
</cffunction>

<cffunction name="onRequestStart12" localmode="modern" output="yes">
	<cfscript>
	var loginCom=0;
	if(structkeyexists(form,'zlogout')){
		application.zcore.user.logOut();
	}
	if(structkeyexists(cookie, 'ztoken')){
		application.zcore.user.verifyToken();
	}
	if(form[request.zos.urlRoutingParameter] EQ "/z/user/login/confirmToken"){
		loginCom=createobject("component", "zcorerootmapping.mvc.z.user.controller.login");
		loginCom.confirmToken();
	}
	// temporarily showing all the time because I don't know how to ensure it runs once.
	if(structkeyexists(cookie,'zparentlogincheck') EQ false and application.zcore.user.checkGroupAccess("user") EQ false){
		application.zcore.user.displayTokenScripts();
	} 
	
	if(request.zos.isDeveloper and structkeyexists(request.zos,'userSession') and structkeyexists(request.zos.userSession.groupAccess, "member")){
		application.zcore.skin.disableMinCat();
	}
	if(structkeyexists(application.sitestruct[request.zos.globals.id],'globalHTMLHeadSourceArrCSS') EQ false or (structkeyexists(application.sitestruct[request.zos.globals.id],'app') and (request.zos.zreset EQ "all" or request.zos.zreset EQ "site" or request.zos.zreset EQ "app") or structkeyexists(application.sitestruct[request.zos.globals.id].skinObj,'curCompiledVersionNumber') EQ false)){
		lock name="#request.zos.zcoreRootPath#-compilePackage" type="exclusive" timeout="30" throwontimeout="yes"{
			if(structkeyexists(application.sitestruct[request.zos.globals.id],'globalHTMLHeadSourceArrCSS') EQ false or (structkeyexists(application.sitestruct[request.zos.globals.id],'app') and (request.zos.zreset EQ "all" or request.zos.zreset EQ "site" or request.zos.zreset EQ "app") or structkeyexists(application.sitestruct[request.zos.globals.id].skinObj,'curCompiledVersionNumber') EQ false)){
					application.zcore.skin.compilePackage();
			}
		}
	}
	
	if(request.zos.istestserver){
		request.searchServerCollectionName="entiresite-"&variables.site_id;
	} 
	request.zos.sslManagerEnabled=false;
	request.zos.currentHostName=request.zos.globals.domain;
	if(application.zcore.functions.zso(request.zos.globals, 'sslManagerDomain') NEQ ""){
		if(request.zos.globals.sslManagerDomain EQ request.zos.cgi.http_host){
			if(request.zos.cgi.server_port EQ 443){
				request.zos.domainAliasMatchFound=true; 
				request.zos.currentHostName='https://'&lcase(request.zos.cgi.http_host); 
				request.zRootDomain=request.zos.globals.sslManagerDomain;
				request.zCookieDomain=request.zos.globals.sslManagerDomain;
				request.zRootPath=replace(request.zos.globals.homedir, request.zos.sitesPath, '');
				request.zRootSecurePath=replace(request.zos.globals.privatehomedir, request.zos.sitesWritablePath, '');
				request.zOSHomeDir=request.zos.sitesPath&request.zRootPath; 
				request.zRootPath="/"&request.zRootPath;
				request.zRootCfcPath="jetendo-sites-writable."&replace(replace(request.zRootSecurePath,".","_","all"),"/",".","ALL")&".";  
				request.zos.sslManagerEnabled=true;
			}else{
				redirectURL='https://'&lcase(request.zos.globals.sslManagerDomain)&request.zos.originalURL&"?"&request.zos.cgi.query_string;  
				application.zcore.functions.z301Redirect(redirectURL);
			}
		}else if(application.zcore.user.checkGroupAccess("member")){
			redirectURL='https://'&lcase(request.zos.globals.sslManagerDomain)&request.zos.originalURL&"?"&request.zos.cgi.query_string;  
			application.zcore.functions.z301Redirect(redirectURL);
		}
	}  
	if(not request.zos.sslManagerEnabled){
		if(not request.zos.istestserver and variables.site_id EQ request.zos.globals.serverid){
			
			/*disabled while out of town.
			if(structkeyexists(request.zos.adminIpStruct, request.zos.cgi.remote_addr) EQ false){
				writeoutput('Access Denied');
				application.zcore.functions.zabort();
			}*/
			if(request.zos.cgi.server_port NEQ 443 and request.zos.isServer EQ false){
				//application.zcore.functions.z301redirect(request.zOS.zcoreAdminDomain&request.cgi_script_name&'?'&cgi.QUERY_STRING);	
			}
		}else if(request.zos.cgi.server_port EQ 443){
			if(replace(replace(request.zos.globals.securedomain,"http://",""),"https://","") NEQ request.zos.cgi.http_host){
				application.zcore.functions.z404("Secure domain doesn't match http_host.");	
			}
		}else if(replace(replace(request.zos.globals.domain,"http://",""),"https://","") NEQ request.zos.cgi.http_host){
			if(request.zos.globals.domainaliases NEQ ""){
				request.zos.arrDomainAliases=listtoarray(request.zos.globals.domainaliases,",");
				request.zos.domainAliasMatchFound=false;
				for(request.zos.__t99=1;request.zos.__t99 LTE arraylen(request.zos.arrDomainAliases);request.zos.__t99++){
					if(request.zos.cgi.http_host EQ request.zos.arrDomainAliases[request.zos.__t99]){
						request.zos.domainAliasMatchFound=true;
						request.zos.currentHostName='http://'&lcase(request.zos.cgi.http_host); 
						    request.zRootDomain=replace(replace(lcase(replace(replace(request.zos.globals.domain, "http://",""), "https://", "")),"www.",""),"."&request.zos.testDomain,"");
						    request.zCookieDomain=replace(lcase(request.zRootDomain),"www.","");
						    request.zRootPath="/"&replace(request.zRootDomain,".","_","all")&"/";
						    request.zOSHomeDir=request.zos.sitesPath&replace(request.zRootDomain,".","_","all")&"/"; 
						    request.zRootSecureCfcPath="jetendo-sites-writable."&replace(replace(request.zRootDomain,".","_","all"),"/",".","ALL")&".";
						    request.zRootCfcPath=replace(replace(request.zRootDomain,".","_","all"),"/",".","ALL")&".";  
						break;	
					}
				}
				if(request.zos.domainAliasMatchFound EQ false){
					application.zcore.functions.z404("Domain alias match not found");
				}
			}else{
				application.zcore.functions.z404("System domain doesn't match host name.");	
			}
		}
	}
	if(structkeyexists(form,request.zos.urlRoutingParameter) and form[request.zos.urlRoutingParameter] NEQ ""){
		 request.cgi_script_name=application.zcore.routing.processInternalURLRewrite(form[request.zos.urlRoutingParameter]);
		if(structkeyexists(form,'zdebugurl') and form.zdebugurl){
			writedump(form);
			writeoutput('processInternalURLRewrite:'&form[request.zos.urlRoutingParameter]&"<br />"&request.cgi_script_name&"<br />");
		}
	}
	request.zos.cgi.script_name=request.cgi_script_name;
	
	
	if(structkeyexists(form,'__zcoreinternalroutingpath') and len(form.__zcoreinternalroutingpath)-4 GT 0){
		request.zos.cgi.SCRIPT_NAME="/z/_#left(form.__zcoreinternalroutingpath,len(form.__zcoreinternalroutingpath)-4)#";
	}
	//request.zos.globals.domain=request.zos.currentHostName;
	request.officeEmail=request.zos.globals.emailCampaignFrom;
	if(application.zcore.functions.zvarso('zofficeemail') NEQ ""){
		request.officeEmail= application.zcore.functions.zvarso('zofficeemail');
	}
	if(request.zos.globals.emailCampaignFrom NEQ ""){
		request.fromemail=request.zos.globals.emailCampaignFrom;
	}else if(request.officeEmail NEQ ""){
		request.fromemail=listgetat(request.officeEmail,1,",");
	}else{
		request.fromemail=request.zos.developerEmailFrom;
	}
	
	
	</cfscript>
</cffunction>

<cffunction name="onRequestStart2" localmode="modern" output="yes">
	<cfscript>
	
	request.zos.emailData={
		sitePath:'/e/attachments/',
		from:'',
		absPath:request.zos.globals.serverhomedir&'static/e/attachments/',
		popserver:request.zos.globals.emailpopserver,
		username:request.zos.globals.emailusername,
		password:request.zos.globals.emailpassword,
		zemail_account_id:false
	};
	
	request.zos.httpCompressionType="deflate;q=0.5";
	request.zos.searchServerCollectionName="entiresite_verity";
	
	if(request.zos.istestserver){
		request.zos.searchServerCollectionName="entiresite-"&variables.site_id;
	}
	if(structkeyexists(form,'zab')){
		Request.zOS.debuggerEnabled=false;
		request.zos.trackingDisabled=true;
	}
	
	// stores a temporary return url
	if(structkeyexists(form, '___zr')){
		session.zos.___zr=form.___zr;
	}
	if(structkeyexists(form, 'zsid') EQ false or isNumeric(form.zsid) EQ false){
		Request.zsid = application.zcore.status.getNewId();
	}else{
		Request.zsid = form.zsid;
	}
	
	
	if(left(request.zos.originalURL, len("/z/server-manager/api/")) EQ "/z/server-manager/api/"){
		
		ts = StructNew();
		ts.secureLogin=true;
		ts.noRedirect=true;
		ts.noLoginForm=true;
		ts.usernameLabel = "E-Mail Address";
		ts.loginMessage = "Please login";
		ts.template = "zcorerootmapping.templates.blank";
		ts.user_group_name = "serveradministrator";
		rs=application.zcore.user.checkLogin(ts);
		if(not rs.success){
			ts={
				success:false,
				errorMessage: "API login failed."
			}
			application.zcore.functions.zReturnJSON(ts);	
		}
		if(request.zos.originalURL EQ "/z/server-manager/api/server/executeCacheReset"){
			// manually execute reset because on needing to call functions that are in Application.cfc
			this.onExecuteCacheReset();
		}
		
	}
	if(request.zos.zreset EQ "code" or request.zos.zreset EQ "all"){
		variables.onCodeDeploy();
	}else if(structkeyexists(application.zcore, 'runOnCodeDeploy')){
		structdelete(application.zcore, 'runOnCodeDeploy');
		variables.onCodeDeploy();
	}
	
	//request.zOS.page.forceSynchronization = true;
	
	if(variables.site_id EQ request.zos.globals.serverid){
		if(structkeyexists(form,'zOpenIdDomain')){
			application.zcore.functions.zredirect(application.zcore.functions.zURLAppend(form.zOpenIdDomain, "zOpenIdGlobalLogin=1&zOpenIdDomainOriginal="&urlencodedformat(form.zOpenIdDomain)&"&"&request.zos.cgi.QUERY_STRING));
		}
	}
	request.zos.inMemberArea=false;
	local.requireMemberAreaLogin=false;
	if(left(request.cgi_script_name, 8) EQ "/member/" or (variables.site_id EQ request.zos.globals.serverid and request.zos.isServer EQ false and form[request.zos.urlRoutingParameter] NEQ "/z/user/login/serverToken")){
		local.requireMemberAreaLogin=true;	
	}
	if(local.requireMemberAreaLogin and structkeyexists(request.zos.adminIpStruct, request.zos.cgi.remote_addr) and request.zos.adminIpStruct[request.zos.cgi.remote_addr] EQ false and left(form[request.zos.urlRoutingParameter], 39) EQ "/z/server-manager/tasks/deploy-archive/"){
		local.requireMemberAreaLogin=false;	
	}
	var ipStruct={};
	var loginBypassIp=application.zcore.functions.zso(request.zos.globals, 'requireLoginByPassIpList');
	if(loginBypassIp NEQ ""){
		var arrIp=listToArray(loginBypassIp, ",");
		for(var i=1;i LTE arrayLen(arrIp);i++){
			ipStruct[arrIp[i]]=true;
		}
	} 
	if(request.zos.globals.parentId NEQ 0){
		loginBypassIp=application.zcore.functions.zvar('requireLoginByPassIpList', request.zos.globals.parentId);
		if(loginBypassIp NEQ ""){
			var arrIp=listToArray(loginBypassIp, ",");
			for(var i=1;i LTE arrayLen(arrIp);i++){
				ipStruct[arrIp[i]]=true;
			}
		} 
	}
	if(not request.zos.isServer and ((request.zos.globals.requireLogin EQ 1 and not structkeyexists(ipStruct, request.zos.cgi.remote_addr) and request.zos.cgi.HTTP_USER_AGENT DOES NOT CONTAIN "W3C_Validator") or local.requireMemberAreaLogin)){
		if(request.cgi_script_name NEQ "/z/user/login/parentToken" and request.cgi_script_name NEQ "/z/user/login/serverToken" and request.cgi_script_name NEQ "/z/user/login/confirmToken"){
			if(request.zos.migrationMode){
				writeoutput('<h2>Server Migration In Progress</h2><p>Please try again in a few hours.</p>');
				application.zcore.functions.zabort();
			}
			if(local.requireMemberAreaLogin){
				request.zos.inMemberArea=true;
				application.zcore.skin.disableMinCat(); 
				if(application.zcore.functions.zso(request.zos.globals, 'sslManagerDomain') NEQ "" and not request.zos.sslManagerEnabled and request.zos.globals.sslManagerDomain NEQ request.zos.currentHostName){
					redirectURL='https://'&lcase(request.zos.globals.sslManagerDomain)&request.zos.originalURL&"?"&request.zos.cgi.query_string;  
					application.zcore.functions.z301Redirect(redirectURL);
				}
			}
			if(application.zcore.user.isCustomSet() EQ false){
				application.zcore.user.setCustomTable();
			}
			request.disablesharethis=true;
			// don't try to login again when already logged in
			if(not application.zcore.user.checkGroupAccess("user")){
				local.inputStruct = StructNew();
				if(request.zos.globals.requireSecureLogin EQ 1){
					inputStruct.secureLogin=true;
				}else{
					inputStruct.secureLogin=false;
				}
				local.inputStruct.usernameLabel = "E-Mail Address";
				local.inputStruct.loginMessage = "Please login";
				local.inputStruct.template = "zcorerootmapping.templates.blank";
				local.inputStruct.user_group_name = "user";
				application.zcore.user.checkLogin(local.inputStruct);
			}
			if(left(request.cgi_script_name, 8) EQ "/member/" or (variables.site_id EQ request.zos.globals.serverid and request.zos.isServer EQ false)){ 
				application.zcore.template.setTemplate("zcorerootmapping.templates.administrator",true,true);
			}
		}
	}else if(request.cgi_script_name EQ "/z/user/login/index"){ 
		request.zos.inMemberArea=true;
		application.zcore.skin.disableMinCat();
	} 
	//if(request.zos.inMemberArea){
		/*for(local.i in url){
			if(isSimpleValue(url[local.i])){
				if(url[local.i] CONTAINS request.zos.globals.domain&"/"){
					url[local.i]=replacenocase(url[local.i], request.zos.globals.domain&"/","/", "all");
				}
				if(url[local.i] CONTAINS request.zos.currentHostName&"/"){
					url[local.i]=replacenocase(url[local.i], request.zos.currentHostName&"/","/", "all");
				}
			}
		}*/
		siteDomain=application.zcore.functions.zvar('domain');
		siteSecureDomain=application.zcore.functions.zvar('securedomain');
		if(siteSecureDomain EQ siteDomain){
			siteSecureDomain="";
		}
		siteDomain2=request.zos.currentHostName;
		if(siteDomain2 EQ siteDomain){
			siteDomain2="";
		}
		for(local.i in form){
			if(isSimpleValue(form[local.i])){
				if(form[local.i] CONTAINS siteDomain&"/"){
					form[local.i]=replacenocase(form[local.i], siteDomain&"/","/", "all");
				}
				if(len(siteSecureDomain)){
					if(form[local.i] CONTAINS siteSecureDomain&"/"){
						form[local.i]=replacenocase(form[local.i], siteSecureDomain&"/","/", "all");
					}
				}
				if(len(siteDomain2)){
					if(form[local.i] CONTAINS siteDomain2&"/"){
						form[local.i]=replacenocase(form[local.i], siteDomain2&"/","/", "all");
					}
				}
			}
		}
	//}
	if(structkeyexists(form,'zab') EQ false){
		application.zcore.tracking.init();
	}
	application.zcore.functions.zRequireJquery();
	</cfscript>
</cffunction>

<cffunction name="onRequestStart3" localmode="modern" output="yes">
	<cfscript>
	/*if(isDefined('session.zos.user.id')){
		request.zDBCacheTimeSpan=createtimespan(0,0,0,0);	
	}else{*/
		request.zDBCacheTimeSpan=createtimespan(0,0,0,0);
	// } 
	
	/*if(variables.site_id NEQ request.zos.globals.serverid){
		if(left(request.cgi_script_name, 18) EQ "/z/server-manager/"){
			if(request.zos.istestserver){
				application.zcore.functions.z404("Server manager is only accessible via <a href=""#request.zOS.zcoreTestAdminDomain#/"">#request.zOS.zcoreTestAdminDomain#/</a>.");	
			}else{
				application.zcore.functions.z404("Server manager is only accessible via <a href=""#request.zOS.zcoreAdminDomain#"">#request.zOS.zcoreAdminDomain#</a>.");	
			}
		}	
	}*/
	
	if(request.zos.istestserver and application.zcore.imageLibraryLastDeleteDate NEQ dateformat(now(),"yyyymmdd")){
		application.zcore.imageLibraryLastDeleteDate=dateformat(now(),"yyyymmdd");
		application.zcore.imageLibraryCom.deleteInactiveImageLibraries(true);
	}
  
	// zld = z login dump, this variable is a status session id that holds data from a login that is recreated after login
	if(structkeyexists(form, 'zld')){
		application.zcore.functions.zStatusHandler(form.zld,true,true);
	}
	application.zcore.template.prependContent(trim(application.zcore.app.onRequestStart()));
	
	if(structkeyexists(request.zos,'scriptNameTemplate') EQ false){
		request.zos.scriptNameTemplate=cgi.script_name;
	}else{
		if(left(request.zos.scriptNameTemplate, 16) NEQ "/jetendo-themes/"){
			request.zos.scriptNameTemplate=request.zrootpath&removechars(request.zos.scriptNameTemplate,1,1);
		}
	}
	if(structkeyexists(form, 'zdebugurl') and form.zdebugurl){
		writeoutput("request.zos.scriptNameTemplate:"&request.zos.scriptNameTemplate&"<br />");
		application.zcore.functions.zabort();
	}
	
	if(request.zos.isDeveloper and request.zos.thisistestserver){
		if(form[request.zos.urlRoutingParameter] CONTAINS "/z/test/"){
			if(request.zos.globals.enableDemoMode NEQ "1"){
				application.zcore.template.fail("Test cases must be run on a demo web site with all application features enabled.");
			}
		}
	}
	</cfscript>

</cffunction>

<cffunction name="onRequestStart4" localmode="modern" output="yes"><cfscript>
	var local={};
	var i=0;
	var template=0;
	var cfcatch=0;
	// silenced output
	savecontent variable="local.output"{
		if(request.zos.inServerManager){
			application.zcore.template.setTag("stylesheet","/z/stylesheets/manager.css",false);
			application.zcore.template.requireTag("title");
			application.zcore.template.setTag("title","Server Manager");
			if(not structkeyexists(session, 'global_zsites_id')){
				session.global_zsites_id = ",,,";
			}
			if(structkeyexists(form,'global_zsites_id1')){
				session.global_zsites_id = form.global_zsites_id1&","&form.global_zsites_id2&","&form.global_zsites_id3;
			}
			// init site navbar
			if(structkeyexists(form,'zid') EQ false){
				form.zid = application.zcore.status.getNewId();
			}
			if(structkeyexists(form,'zIndex')){
				application.zcore.status.setField(form.zid, "zIndex", form.zIndex);
			}else{
				form.zIndex = application.zcore.status.getField(form.zid, "zIndex");
				if(form.zIndex EQ ""){
					form.zIndex = 1;
				}
			}	
			Request.zScriptName = request.cgi_script_name&"?zid=#form.zid#";
			if((isDefined('session.zos.user.id') or left(request.cgi_script_name, 24) NEQ '/z/server-manager/tasks/') and structkeyexists(form, 'zhidetopnav') eq false){
				application.zcore.template.setTag("secondnav",application.zcore.functions.zOS_getSiteNav(form.zid));
			}else if(not request.zos.isServer and not request.zos.isDeveloperIPMatch){
				application.zcore.functions.z404("Only logged on developer users or the server itself can access this url.");	
			}
		}
		if(structkeyexists(application.sitestruct[request.zos.globals.id],'zcorecustomfunctions')){
			structappend(variables, application.sitestruct[request.zos.globals.id].zcorecustomfunctions, true);
		}
		if(structkeyexists(application.sitestruct[request.zos.globals.id],'onSiteRequestStartEnabled') and application.sitestruct[request.zos.globals.id].onSiteRequestStartEnabled){
			application.sitestruct[request.zos.globals.id].zcorecustomfunctions.onSiteRequestStart(variables);
		}
		application.zcore.functions.zIncludeZOSFORMS();
		try{
			login applicationtoken="#application.applicationname#"{
			}
			if(isDefined('session.zos.user.groupAccess') EQ false or structkeyexists(form,'zLogOut')){
				logout;
			}else if(structkeyexists(session.zos, 'user')){
				if(session.zos.secureLogin){
					local.roles = structkeylist(session.zos.user.groupAccess);
				}else{
					local.roles="user";
				}
				local.pass=hash(request.zos.now&request.zos.zcoremapping&"+|secureKey");
				loginuser name="#session.zos.user.email#" password="#local.pass#" roles="#local.roles#";
			}
		}catch(Any local.e){
			local.roles="";
		}
	}
	application.zcore.routing.processRequestURL(request.zos.cgi.SCRIPT_NAME);
	</cfscript>
</cffunction>

</cfoutput>