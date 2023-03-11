/* Migration 000054_create_crt_channelmembership_count.up sets
   ChannelMembers.LastUpdateAt to the results of SELECT ROUND(UNIX_TIMESTAMP(NOW(3))*1000)
   which will be different each time the migration is run. Thus, the column will always be
   different when comparing the server and script migrations. To bypass this, we update all
   rows in ChannelMembers so that they contain the same value for such column. */
UPDATE ChannelMembers SET LastUpdateAt = 1;

/* Migration 000055_create_crt_thread_count_and_unreads.up sets
   ThreadMemberships.LastUpdated to the results of SELECT ROUND(UNIX_TIMESTAMP(NOW(3))*1000)
   which will be different each time the migration is run. Thus, the column will always be
   different when comparing the server and script migrations. To bypass this, we update all
   rows in ThreadMemberships so that they contain the same value for such column. */
UPDATE ThreadMemberships SET LastUpdated = 1;

/* The security update check in the server may update the LastSecurityTime system value. To
   avoid any spurious difference in the migrations, we update it to a fixed value. */
UPDATE Systems SET Value = 1 WHERE Name = 'LastSecurityTime';

/* The server migration may contain a row in the Systems table marking the onboarding as complete.
   There are no migrations related to this, so we can simply drop it here. */
DELETE FROM Systems WHERE Name = 'FirstAdminSetupComplete';

/* The server migration contains an in-app migration that adds new roles for Playbooks:
   doPlaybooksRolesCreationMigration, defined in https://github.com/mattermost/mattermost-server/blob/282bd351e3767dcfd8c8340da2e0915197c0dbcb/app/migrations.go#L345-L469
   The roles are the ones defined in https://github.com/mattermost/mattermost-server/blob/282bd351e3767dcfd8c8340da2e0915197c0dbcb/model/role.go#L874-L929
   When this migration finishes, it also adds a new row to the Systems table with the key of the migration.
   This in-app migration does not happen in the script, so we remove those rows here. */
DELETE FROM Roles WHERE Name = 'playbook_member';
DELETE FROM Roles WHERE Name = 'playbook_admin';
DELETE FROM Roles WHERE Name = 'run_member';
DELETE FROM Roles WHERE Name = 'run_admin';
DELETE FROM Systems WHERE Name = 'PlaybookRolesCreationMigrationComplete';

/* The server migration contains two in-app migrations that add playbooks permissions to certain roles:
    getAddPlaybooksPermissions and getPlaybooksPermissionsAddManageRoles, defined in https://github.com/mattermost/mattermost-server/blob/282bd351e3767dcfd8c8340da2e0915197c0dbcb/app/permissions_migrations.go#L1021-L1072
    The specific roles ('%playbook%') are removed in the procedure below, but the migrations also add new rows to the Systems table marking the migrations as complete.
    These in-app migrations do not happen in the script, so we remove those rows here. */
DELETE FROM Systems WHERE Name = 'playbooks_manage_roles';
DELETE FROM Systems WHERE Name = 'playbooks_permissions';

/* The server migration contains an in-app migration that adds boards permissions to certain roles:
   getProductsBoardsPermissions, defined in https://github.com/mattermost/mattermost-server/blob/282bd351e3767dcfd8c8340da2e0915197c0dbcb/app/permissions_migrations.go#L1074-L1093
   The specific roles (sysconsole_read_product_boards and sysconsole_write_product_boards) are removed in the procedure below,
   but the migrations also adds a new row to the Systems table marking the migrations as complete.
   This in-app migration does not happen in the script, so we remove that rows here. */
DELETE FROM Systems WHERE Name = 'products_boards';

/* TODO: REVIEW STARTING HERE */

/* doRemainingSchemaMigrations adds an ID to the TeamInviteId column in the Teams table. Something like:
       Get all affected teams with SELECT * FROM Teams WHERE InviteId = ''
       For each of the previous team, generate a newID and run UPDATE Teams SET InviteId = newID WHERE ...
   At the end of such migration, a new row to the Systems table is added. We drop it here */
DELETE FROM Systems WHERE Name = 'RemainingSchemaMigrations';

/* doCustomGroupAdminRoleCreationMigration adds a new role and mark this migration as complete. The new role is:
       roles[SystemCustomGroupAdminRoleId] = &Role{
           Name:          "system_custom_group_admin",
           DisplayName:   "authentication.roles.system_custom_group_admin.name",
           Description:   "authentication.roles.system_custom_group_admin.description",
           Permissions:   SystemCustomGroupAdminDefaultPermissions,
           SchemeManaged: false,
           BuiltIn:       true,
       }

   The permissions contain:
       SystemCustomGroupAdminDefaultPermissions = []string{
           PermissionCreateCustomGroup.Id,         // create_custom_group
           PermissionEditCustomGroup.Id,           // edit_custom_group
           PermissionDeleteCustomGroup.Id,         // delete_custom_group
           PermissionRestoreCustomGroup.Id,        // restore_custom_group
           PermissionManageCustomGroupMembers.Id,  // manage_custom_group_members
       }
   The ID of the role will change, so we need to standardize it */
DELETE FROM Roles WHERE Name = 'system_custom_group_admin';
DELETE FROM Systems WHERE Name = 'CustomGroupAdminRoleCreationMigrationComplete';


/* doPostPriorityConfigDefaultTrueMigration updates the config, setting ServiceSettings.PostPriority to true,
   and marking this migration as complete in the Systems table. The migration script will not contain this
   migration, so it's safe to clean it up here. */
DELETE FROM Systems WHERE Name = 'PostPriorityConfigDefaultTrueMigrationComplete';

/* getAddCustomUserGroupsPermissions and getAddCustomUserGroupsPermissionRestore adds two rows to the Systems
   table to mark those migrations as complete. The migrations are the following:
       func (a *App) getAddCustomUserGroupsPermissions() (permissionsMap, error) {
           t := []permissionTransformation{}

           customGroupPermissions := []string{
               model.PermissionCreateCustomGroup.Id,
               model.PermissionManageCustomGroupMembers.Id,
               model.PermissionEditCustomGroup.Id,
               model.PermissionDeleteCustomGroup.Id,
           }

           t = append(t, permissionTransformation{
               On:  isExactRole(model.SystemUserRoleId),
               Add: customGroupPermissions,
           })

           t = append(t, permissionTransformation{
               On:  isExactRole(model.SystemAdminRoleId),
               Add: customGroupPermissions,
           })

           return t, nil
       }


       func (a *App) getAddCustomUserGroupsPermissionRestore() (permissionsMap, error) {
           t := []permissionTransformation{}

           customGroupPermissions := []string{
               model.PermissionRestoreCustomGroup.Id,
           }

           t = append(t, permissionTransformation{
               On:  isExactRole(model.SystemUserRoleId),
               Add: customGroupPermissions,
           })

           t = append(t, permissionTransformation{
               On:  isExactRole(model.SystemAdminRoleId),
               Add: customGroupPermissions,
           })

           t = append(t, permissionTransformation{
               On:  isExactRole(model.SystemCustomGroupAdminRoleId),
               Add: customGroupPermissions,
           })
           return t, nil
   It's safe to let these migrations run only in the server, so we can remove the Systems rows for diff. */
DELETE FROM Systems WHERE Name = 'custom_groups_permissions';
DELETE FROM Systems WHERE Name = 'custom_groups_permission_restore';


UPDATE Roles SET UpdateAt = 1;


SET group_concat_max_len = 18446744073709551615;

DROP PROCEDURE IF EXISTS splitString;
DROP PROCEDURE IF EXISTS sortPermissionsInRoles;

DROP TEMPORARY TABLE IF EXISTS temp_roles;
CREATE TEMPORARY TABLE temp_roles(id varchar(26), permission longtext);

DELIMITER //

CREATE PROCEDURE splitPermissions(
  IN id varchar(26),
  IN permissionsString longtext
)
BEGIN
  DECLARE idx INT DEFAULT 0;
  SELECT TRIM(permissionsString) INTO permissionsString;
  SELECT LOCATE(' ', permissionsString) INTO idx;
  WHILE idx > 0 DO
    INSERT INTO temp_roles SELECT id, TRIM(LEFT(permissionsString, idx));
    SELECT SUBSTR(permissionsString, idx+1) INTO permissionsString;
    SELECT LOCATE(' ', permissionsString) INTO idx;
  END WHILE;
  INSERT INTO temp_roles(id, permission) VALUES(id, TRIM(permissionsString));
END; //

CREATE PROCEDURE sortPermissionsInRoles()
BEGIN
  DECLARE done INT DEFAULT FALSE;
  DECLARE rolesId varchar(26) DEFAULT '';
  DECLARE rolesPermissions longtext DEFAULT '';
  DECLARE cur1 CURSOR FOR SELECT Id, Permissions FROM Roles;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

  OPEN cur1;
  read_loop: LOOP
    FETCH cur1 INTO rolesId, rolesPermissions;
    IF done THEN
      LEAVE read_loop;
    END IF;
    CALL splitPermissions(rolesId, rolesPermissions);
  END LOOP;
  CLOSE cur1;

  DELETE FROM temp_roles WHERE permission LIKE 'sysconsole_read_products_boards';
  DELETE FROM temp_roles WHERE permission LIKE 'sysconsole_write_products_boards';
  DELETE FROM temp_roles WHERE permission LIKE '%playbook%';
  DELETE FROM temp_roles WHERE permission LIKE '%custom_group%';
  DELETE FROM temp_roles WHERE permission LIKE 'run_create';
  DELETE FROM temp_roles WHERE permission LIKE 'run_manage_members';
  DELETE FROM temp_roles WHERE permission LIKE 'run_manage_properties';
  DELETE FROM temp_roles WHERE permission LIKE 'run_view';

  UPDATE
    Roles INNER JOIN (
      SELECT temp_roles.id as Id, TRIM(group_concat(temp_roles.permission ORDER BY temp_roles.permission SEPARATOR ' ')) as Permissions
        FROM Roles JOIN temp_roles ON Roles.Id = temp_roles.id
        GROUP BY temp_roles.id
    ) AS Sorted
    ON Roles.Id = Sorted.Id
    SET Roles.Permissions = Sorted.Permissions;
END; //
DELIMITER ;

CALL sortPermissionsInRoles();

DROP TEMPORARY TABLE IF EXISTS temp_roles;

SET group_concat_max_len = 1024;
