<cfcomponent implements="zcorerootmapping.interface.databaseVersion">
<cfoutput>
<cffunction name="getChangedTableArray" localmode="modern" access="public" returntype="array">
	<cfscript>
	arr1=[];
	return arr1;
	</cfscript>
</cffunction>

<cffunction name="executeUpgrade" localmode="modern" access="public" returntype="boolean">
	<cfargument name="dbUpgradeCom" type="component" required="yes">
	<cfscript>
	if(!arguments.dbUpgradeCom.executeQuery(this.datasource, "ALTER TABLE `site`   
  ADD COLUMN `site_disable_dns_monitor` CHAR(1) DEFAULT '0'   NOT NULL AFTER `site_nginx_disable_jetendo`")){
		return false;
	}

	return true;
	</cfscript>
</cffunction>
</cfoutput>
</cfcomponent>