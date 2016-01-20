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
	if(!arguments.dbUpgradeCom.executeQuery(this.datasource, "ALTER TABLE `site_x_option_group_set`   
  ADD COLUMN `site_x_option_group_set_user` VARCHAR(15) NOT NULL AFTER `site_x_option_group_set_copy_id`")){
		return false;
	}   
	return true;
	</cfscript>
</cffunction>
</cfoutput>
</cfcomponent>