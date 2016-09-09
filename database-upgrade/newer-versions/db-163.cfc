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

	sql = "ALTER TABLE `job`
ADD COLUMN `job_search`  longtext NOT NULL AFTER `job_suggested_by_phone`,
ADD FULLTEXT INDEX `NewIndex4` (`job_search`)
";

	if(!arguments.dbUpgradeCom.executeQuery(this.datasource, sql)){
		return false;
	}    

	return true;
	</cfscript>
</cffunction>
</cfoutput>
</cfcomponent>