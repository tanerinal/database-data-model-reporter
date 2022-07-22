/************************************************************************************************************************
Important notes: 
1. Change "schema_name" and "table_name" phrases according to your data model.
2. Refactor Insert statements according to your data model.

************************************************************************************************************************/
CREATE OR REPLACE TRIGGER schema_name.trg_table_name
    BEFORE INSERT OR UPDATE OR DELETE
    ON schema_name.table_name
    REFERENCING NEW AS new OLD AS old
    FOR EACH ROW
DECLARE
    v_log_machine    VARCHAR2 (64);
    v_log_osuser     VARCHAR2 (30);
    v_dml_type       VARCHAR2 (15);
    v_old_new        VARCHAR2 (30);
    v_log_module     VARCHAR2 (64);
    v_log_clientip   VARCHAR2 (60);
    v_log_username   VARCHAR2 (200) := '';
    v_log_ldapuser   VARCHAR2 (200) := '';
    v_request        VARCHAR2 (200) := '';
    v_reason         VARCHAR2 (200) := '';
BEGIN
    v_log_machine := SYS_CONTEXT ('userenv', 'host');
    v_log_clientip := SYS_CONTEXT ('userenv', 'ip_address');
    v_log_osuser := SYS_CONTEXT ('userenv', 'os_user');
    v_log_ldapuser := SYS_CONTEXT ('userenv', 'os_user');
    v_request := SYS_CONTEXT ('APP_USERENV', 'REQUEST_ID');
    v_reason := SYS_CONTEXT ('APP_USERENV', 'REASON');
    v_log_module := SYS_CONTEXT ('userenv', 'module');
    v_log_username := SYS_CONTEXT ('userenv', 'SESSION_USER');

    IF INSERTING
    THEN
        v_dml_type := 'I';
        v_old_new := 'NEW';

        INSERT INTO table_name_log (log_date,
                                    dml_type,
                                    old_new,
                                    log_username,
                                    log_ldapuser,
                                    log_machine,
                                    log_osuser,
                                    log_clientip,
                                    log_module,
                                    requestid,
                                    reason,
                                    column_1,
                                    column_2,
                                    column_3)
             VALUES (SYSDATE,
                     v_dml_type,
                     v_old_new,
                     v_log_username,
                     v_log_ldapuser,
                     v_log_machine,
                     v_log_osuser,
                     v_log_clientip,
                     v_log_module,
                     v_request,
                     v_reason,
                     :new.column_1,
                     :new.column_2,
                     :new.column_3);
    ELSIF UPDATING
    THEN
        v_dml_type := 'U';
        v_old_new := 'OLD';

        INSERT INTO table_name_log (log_date,
                                    dml_type,
                                    old_new,
                                    log_username,
                                    log_ldapuser,
                                    log_machine,
                                    log_osuser,
                                    log_clientip,
                                    log_module,
                                    requestid,
                                    reason,
                                    column_1,
                                    column_2,
                                    column_3)
             VALUES (SYSDATE,
                     v_dml_type,
                     v_old_new,
                     v_log_username,
                     v_log_ldapuser,
                     v_log_machine,
                     v_log_osuser,
                     v_log_clientip,
                     v_log_module,
                     v_request,
                     v_reason,
                     :old.column_1,
                     :old.column_2,
                     :old.column_3);

        v_old_new := 'NEW';

        INSERT INTO table_name_log (log_date,
                                    dml_type,
                                    old_new,
                                    log_username,
                                    log_ldapuser,
                                    log_machine,
                                    log_osuser,
                                    log_clientip,
                                    log_module,
                                    requestid,
                                    reason,
                                    column_1,
                                    column_2,
                                    column_3)
             VALUES (SYSDATE,
                     v_dml_type,
                     v_old_new,
                     v_log_username,
                     v_log_ldapuser,
                     v_log_machine,
                     v_log_osuser,
                     v_log_clientip,
                     v_log_module,
                     v_request,
                     v_reason,
                     :new.column_1,
                     :new.column_2,
                     :new.column_3);
    ELSIF DELETING
    THEN
        v_dml_type := 'D';
        v_old_new := 'OLD';

        INSERT INTO table_name_log (log_date,
                                    dml_type,
                                    old_new,
                                    log_username,
                                    log_ldapuser,
                                    log_machine,
                                    log_osuser,
                                    log_clientip,
                                    log_module,
                                    requestid,
                                    reason,
                                    column_1,
                                    column_2,
                                    column_3)
             VALUES (SYSDATE,
                     v_dml_type,
                     v_old_new,
                     v_log_username,
                     v_log_ldapuser,
                     v_log_machine,
                     v_log_osuser,
                     v_log_clientip,
                     v_log_module,
                     v_request,
                     v_reason,
                     :old.column_1,
                     :old.column_2,
                     :old.column_3);
    END IF;
END;