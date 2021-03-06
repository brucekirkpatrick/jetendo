<cfcomponent>
<cfoutput>
<cffunction name="index" localmode="modern" access="remote" roles="member">
	<cfscript>
	var arrKey=0;
	var timeofdayStruct=0;
	var keywordStruct=0;
	var i=0;
	var qC=0;
	var engineStruct=0;
	application.zcore.functions.zSetPageHelpId("4.8");
    application.zcore.adminSecurityFilter.requireFeatureAccess("Lead Reports");

	var db=request.zos.queryObject;
	var hCom=application.zcore.functions.zcreateobject("component", "zcorerootmapping.com.app.inquiriesFunctions");
	hCom.displayHeader();
	form.end_date = application.zcore.functions.zGetDateSelect("end_date");
	form.start_date = application.zcore.functions.zGetDateSelect("start_date");
	if(form.start_date EQ false or form.end_date EQ false){
		if(dateformat(dateadd("d", -30, now()),"yyyymmdd") LT "20100114"){
			form.start_date = "2010-01-14";
		}else{
			form.start_date = dateformat(dateadd("d", -30, now()), "yyyy-mm-dd");
		}
		form.end_date = dateFormat(now(), "yyyy-mm-dd");
	}
	</cfscript>
	<h1>Inquiries Source Report</h1>
	<form action="/z/inquiries/admin/lead-source-report/index?search=true" method="post">
		<input type="hidden" name="searchOn" value="true">
		<table style="border-spacing:0px;" class="table-list">
			<tr>
				<th>Search Leads</th>
				<td style="white-space:nowrap;">Start:#application.zcore.functions.zDateSelect("start_date", "start_date", (2010), year(now()))#</td>
				<td style="white-space:nowrap;">End:#application.zcore.functions.zDateSelect("end_date", "end_date", (2010), year(now()))#</td>
				<td><button type="submit" name="submitForm">Search</button>
					<button type="button" onclick="window.location.href='/z/inquiries/admin/lead-source-report/index';" name="submitForm22">Clear</button></td>
			</tr>
		</table>
	</form>
	<cfsavecontent variable="db.sql"> 
	SELECT track_user.*, IF(track_page.track_user_id IS NULL, #db.param(0)#,#db.param(1)#) adwordsLead 
	FROM #db.table("track_user", request.zos.zcoreDatasource)# track_user 
	LEFT JOIN #db.table("track_page", request.zos.zcoreDatasource)# track_page ON 
	track_user.track_user_id=track_page.track_user_id AND 
	track_page_deleted = #db.param(0)# and 
	( track_page_qs LIKE #db.param('%gclid=%')#) and 
	track_page.site_id = track_user.site_id 
	
	WHERE  track_user_conversions >#db.param(0)# AND 
	track_user_deleted = #db.param(0)# and 
	track_user.site_id = #db.param(request.zos.globals.id)# AND track_user_email <>#db.param('')# and 
	(DATE_FORMAT(track_user_recent_datetime,#db.param("%Y-%m-%d")#) >= #db.param(dateformat(form.start_date, "yyyy-mm-dd"))# and 
	DATE_FORMAT(track_user_datetime,#db.param("%Y-%m-%d")#) <= #db.param(dateformat(form.end_date, "yyyy-mm-dd"))#)
	GROUP BY track_user.track_user_id </cfsavecontent>
	<cfscript>
	qC=db.execute("qC");
	engineStruct=structnew();
	keywordStruct=structnew();
	timeofdayStruct=structnew();
	</cfscript>
	<br />
	<p>The same user submitting more then one lead counts as only one lead on this report.  Only leads since 1/14/2010 are able to be reported here.</p>
	<cfloop query="qC">
		<cfscript>
		ref="";
		seconds=0;
		if(isnull(qC.track_user_datetime) EQ false and isdate(qC.track_user_datetime) and isdate(qC.track_user_recent_datetime)){
			formattedDate=DateFormat(qC.track_user_datetime,'yyyy-mm-dd')&' '&TimeFormat(qC.track_user_datetime,'HH:mm:ss');
			firstDate=parsedatetime(formattedDate);
			formattedDate2=DateFormat(qC.track_user_recent_datetime,'yyyy-mm-dd')&' '&TimeFormat(qC.track_user_recent_datetime,'HH:mm:ss');
			lastDate=parsedatetime(formattedDate2);
			seconds=DateDiff("s", formattedDate, formattedDate2);
			leadTime=timeformat(dateadd("s",seconds/2,formattedDate),"HH");
			if(structkeyexists(timeofdayStruct,leadTime) EQ false){
				timeofdayStruct[leadTime]=structnew();	
				timeofdayStruct[leadTime].count=0;
				timeofdayStruct[leadTime].clicks=arraynew(1);
				timeofdayStruct[leadTime].length=arraynew(1);
			}
			timeofdayStruct[leadTime].count++;
			arrayappend(timeofdayStruct[leadTime].clicks,qC.track_user_hits);
			arrayappend(timeofdayStruct[leadTime].length,seconds);
		}
		if(qC.track_user_referer NEQ ""){
			ref=replacenocase(replacenocase(replacenocase(qC.track_user_referer,"http://",""),"www.",""),"https://","");
			pos=find("/",ref);
			if(pos NEQ 0){
				ref=left(ref,pos-1);
			}
			if(qC.adwordsLead EQ 1){
				ref&=" (adwords pay per click)";	
			}
			if(structkeyexists(engineStruct,ref) EQ false){
				engineStruct[ref]=structnew();	
				engineStruct[ref].count=0;
				engineStruct[ref].clicks=arraynew(1);
				engineStruct[ref].length=arraynew(1);
			}
			engineStruct[ref].count++;
			arrayappend(engineStruct[ref].clicks,qC.track_user_hits);
			arrayappend(engineStruct[ref].length,seconds);
		}
		if(qC.track_user_keywords NEQ ""){
			if(structkeyexists(keywordStruct,qC.track_user_keywords) EQ false){
					keywordStruct[qC.track_user_keywords]=structnew();	
					keywordStruct[qC.track_user_keywords].count=0;
					keywordStruct[qC.track_user_keywords].clicks=arraynew(1);
					keywordStruct[qC.track_user_keywords].length=arraynew(1);
			}
			keywordStruct[qC.track_user_keywords].count++;
			arrayappend(keywordStruct[qC.track_user_keywords].clicks,qC.track_user_hits);
			formattedDate=DateFormat(qC.track_user_datetime,'yyyy-mm-dd')&' '&TimeFormat(qC.track_user_datetime,'HH:mm:ss');
			firstDate=parsedatetime(formattedDate);
			formattedDate2=DateFormat(qC.track_user_recent_datetime,'yyyy-mm-dd')&' '&TimeFormat(qC.track_user_recent_datetime,'HH:mm:ss');
			lastDate=parsedatetime(formattedDate2);
			seconds=DateDiff("s", formattedDate, formattedDate2);
			arrayappend(keywordStruct[qC.track_user_keywords].length,seconds);
		}
		</cfscript>
	</cfloop>
	<h2>Lead Source Report</h2>
	<table style="border-spacing:0px;" class="table-list">
		<tr>
			<th>Lead Source</th>
			<th>## of Leads</th>
			<th>Average Clicks</th>
			<th>Average Length of Visit</th>
		</tr>
		<cfscript>
		arrKey=structkeyarray(engineStruct);
		arraysort(arrKey,"text","asc");
		if(arraylen(arrKey) EQ 0){
			writeoutput('<tr><td colspan="4">No lead data available.</td></tr>');
		}
		for(i=1;i LTE arraylen(arrKey);i++){
			writeoutput('<tr');
			if(i MOD 2 EQ 0){ writeoutput(' style="" '); }
			seconds=round(arrayavg(engineStruct[arrKey[i]].length));
			minutes=fix(seconds/60)&'mins ';
			if(fix(seconds/60) EQ 0){
				minutes="";
			}
			if(seconds MOD 60 NEQ 0){
				minutes=minutes&(seconds MOD 60)&'secs';
			}
			writeoutput('><td>#arrKey[i]#</td><td>#engineStruct[arrKey[i]].count#</td><td>#round(arrayavg(engineStruct[arrKey[i]].clicks))#</td><td>#minutes#</td></tr>');	
		}
		</cfscript>
	</table>
	<br />
	<h2>Keyword Report</h2>
	<table style="border-spacing:0px;" class="table-list">
		<tr>
			<th>Keyword Phrase</th>
			<th>## of Leads</th>
			<th>Average Clicks</th>
			<th>Average Length of Visit</th>
		</tr>
		<cfscript>
		arrKey=structkeyarray(keywordStruct);
		arraysort(arrKey,"text","asc");
		if(arraylen(arrKey) EQ 0){
			writeoutput('<tr><td colspan="4">No lead data available.</td></tr>');
		}
		for(i=1;i LTE arraylen(arrKey);i++){
			writeoutput('<tr');
			if(i MOD 2 EQ 0){ writeoutput(' style="" '); }
			seconds=round(arrayavg(keywordStruct[arrKey[i]].length));
			minutes=fix(seconds/60)&'mins ';
			if(fix(seconds/60) EQ 0){
				minutes="";
			}
			if(seconds MOD 60 NEQ 0){
				minutes=minutes&(seconds MOD 60)&'secs';
			}
			writeoutput('><td>#arrKey[i]#</td><td>#keywordStruct[arrKey[i]].count#</td><td>#round(arrayavg(keywordStruct[arrKey[i]].clicks))#</td><td>#minutes#</td></tr>');	
		}
		</cfscript>
	</table>
	<br />
	<h2>Time of Day Report</h2>
	<table style="border-spacing:0px;" class="table-list">
		<tr>
			<th>Time of Day</th>
			<th>## of Leads</th>
			<th>Average Clicks</th>
			<th>Average Length of Visit</th>
		</tr>
		<cfscript>
		arrKey=structkeyarray(timeofdayStruct);
		arraysort(arrKey,"text","asc");
		if(arraylen(arrKey) EQ 0){
			writeoutput('<tr><td colspan="4">No lead data available.</td></tr>');
		}
		for(i=1;i LTE arraylen(arrKey);i++){
			writeoutput('<tr');
			if(i MOD 2 EQ 0){ writeoutput(' style="" '); }
			seconds=round(arrayavg(timeofdayStruct[arrKey[i]].length));
			minutes=fix(seconds/60)&'mins ';
			if(fix(seconds/60) EQ 0){
				minutes="";
			}
			if(seconds MOD 60 NEQ 0){
				minutes=minutes&(seconds MOD 60)&'secs';
			}
			writeoutput('><td>#timeformat(arrKey[i]&":00:00","h tt")#</td><td>#timeofdayStruct[arrKey[i]].count#</td><td>#round(arrayavg(timeofdayStruct[arrKey[i]].clicks))#</td><td>#minutes#</td></tr>');	
		}
		</cfscript>
	</table>
	<br />
</cffunction>
</cfoutput>
</cfcomponent>
