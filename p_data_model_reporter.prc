CREATE OR REPLACE PROCEDURE schema_name.p_data_model_reporter
IS
    v_mail_body     CLOB;
    counter         NUMBER := 0;
    v_mail_to       VARCHAR2 (100);
    v_mail_from     VARCHAR2 (50);
    v_mail_source   VARCHAR2 (50);
    v_log_table_column_count    NUMBER;
    v_trigger_pure_column_count NUMBER;
    v_trigger_new_column_count  NUMBER;
    v_trigger_old_column_count  NUMBER;
    v_policy_trans_column_count     NUMBER;
    v_policy_table_column_count                 NUMBER;

    PROCEDURE send_mail (p_mail_to        IN VARCHAR2 DEFAULT NULL,
                         p_mail_from      IN VARCHAR2 DEFAULT NULL,
                         p_subject        IN VARCHAR2,
                         p_mail_source    IN VARCHAR2,
                         p_message_body   IN CLOB)
    IS
        invalid_operation   EXCEPTION;                 -- Operation is invalid
        transient_error     EXCEPTION;  -- Transient server error in 400 range
        permanent_error     EXCEPTION;  -- Permanent server error in 500 range
        PRAGMA EXCEPTION_INIT (invalid_operation, -29277);
        PRAGMA EXCEPTION_INIT (transient_error, -29278);
        PRAGMA EXCEPTION_INIT (permanent_error, -29279);
        conn                UTL_SMTP.connection;
        smtp_server         VARCHAR2 (50) := '<change_this>';
        mail_from           VARCHAR2 (50) := p_mail_from;
        mail_from_name      VARCHAR2 (50) := '<change_this>';
        mail_source         VARCHAR2 (100) := p_mail_source;

        --*******************************************************************************--
        PROCEDURE add_message (name IN VARCHAR2, header IN VARCHAR2)
        IS
        BEGIN
            UTL_SMTP.write_data (conn,
                                 name || ': ' || header || UTL_TCP.crlf);
        END;
    BEGIN
        conn := UTL_SMTP.open_connection (smtp_server);
        UTL_SMTP.helo (conn, smtp_server); --identify the domain of the sender
        UTL_SMTP.mail (conn, mail_from); --start a mail, specify the sender which defined by user
        UTL_SMTP.rcpt (conn, p_mail_to);
        UTL_SMTP.open_data (conn);
        add_message ('From', '"' || mail_from_name || '" <' || mail_from || '>');
        add_message ('To', '"Recipient" <' || p_mail_to || '>');
        add_message ('Subject', p_subject || ' (' || 'Source DB:' || mail_source || ')');
        --HTML ENABLING
        add_message ('Content-Disposition', 'inline');
        add_message ('Content-Transfer-Encoding', '7bit');
        add_message ('MIME-Version', '1.0');
        add_message ('Content-Type', 'text/html; charset="iso-8859-9"');
        UTL_SMTP.write_data (conn, UTL_TCP.crlf);

        FOR i IN 1 .. DBMS_LOB.getlength (p_message_body)
        LOOP
            UTL_SMTP.write_data (conn, DBMS_LOB.SUBSTR (p_message_body, 4000, (4000 * counter) + 1));
            counter := counter + 1;
        END LOOP;

        UTL_SMTP.close_data (conn);
        UTL_SMTP.quit (conn);
    END;
BEGIN
    v_mail_body := '<p><strong>Date of Report: ' || TO_CHAR (TRUNC (SYSDATE - 1), 'dd.mm.yyyy') || '</strong></p>';
    v_mail_body := v_mail_body || '<h2>Data Model Changes</h2>';
    v_mail_body := v_mail_body || '
<table style="border: 1px solid black; width:100%;">                                                    
<tr>    
<th style="border: 1px solid black;">Date</th>    
<th style="border: 1px solid black;">User</th>     
<th style="border: 1px solid black;">Schema</th>    
<th style="border: 1px solid black;">Object</th>    
<th style="border: 1px solid black;">Script</th>  
</tr>';

    FOR c
        IN (  SELECT TO_CHAR (action_date, 'dd.mm.yyyy') action_date,
                     action_osuser,
                     action_username,
                     object_name,
                     ddl_sql
                FROM admin.ddl_history_log
               WHERE     object_type = 'TABLE'
                     AND object_owner = UPPER('schema_name')
                     AND ddl IN ('ALTER', 'DROP', 'CREATE')
                     AND action_date BETWEEN TRUNC (SYSDATE - 1) AND TRUNC (SYSDATE)
            ORDER BY action_osuser)
    LOOP
        v_mail_body :=
               v_mail_body
            || '<TR>                                                                          
<TD style="border: 1px solid black;">'
            || TO_CLOB (c.action_date)
            || '</TD>    
<TD style="border: 1px solid black;">'
            || TO_CLOB (c.action_osuser)
            || '</TD>    
<TD style="border: 1px solid black;">'
            || TO_CLOB (c.action_username)
            || '</TD>    
<TD style="border: 1px solid black;">'
            || TO_CLOB (c.object_name)
            || '</TD>    
<TD style="border: 1px solid black;">'
            || TO_CLOB (c.ddl_sql)
            || '</TD>    
</TR>';
    END LOOP;

    v_mail_body := v_mail_body || '</TABLE> ';

    IF INSTR (v_mail_body, '<TR>') = 0
    THEN
        v_mail_body := '<p>Report Date: ' || TO_CHAR (TRUNC (SYSDATE - 1), 'dd.mm.yyyy') || '</p>';
        v_mail_body := v_mail_body || '<h2>Data Model Changes</h2>';
        v_mail_body := v_mail_body || '<p>Not found any data model changes!</p>';
    END IF;
    
    /************************************************************************************************************************/
    
    v_mail_body := v_mail_body || '<hr />';
    v_mail_body := v_mail_body || '<h2>Tables without comments</h2>';
    
    FOR c
        IN (SELECT utcom.table_name
              FROM sys.user_tab_comments  utcom
                   INNER JOIN sys.user_objects uobj ON utcom.table_name = uobj.object_name
             WHERE uobj.object_type = 'TABLE' AND utcom.comments IS NULL)
    LOOP
        v_mail_body := v_mail_body || c.table_name || '<BR />';
    END LOOP;
    
    IF v_mail_body NOT LIKE '%<BR />'
    THEN
        v_mail_body := v_mail_body || '<p>All tables have comments!</p>';
    END IF;
    
    /************************************************************************************************************************/
    
    v_mail_body := v_mail_body || '<hr />';
    v_mail_body := v_mail_body || '<h2>Table columns without comments</h2>';
    
    FOR c
        IN (SELECT ucc.table_name || '.' ||ucc.column_name column_name
              FROM sys.user_col_comments  ucc
                   INNER JOIN sys.user_objects uobj ON ucc.table_name = uobj.object_name
             WHERE uobj.object_type = 'TABLE' AND ucc.comments IS NULL)
    LOOP
        v_mail_body := v_mail_body || c.column_name || '<BR />';
    END LOOP;
    
    IF v_mail_body NOT LIKE '%<BR />'
    THEN
        v_mail_body := v_mail_body || '<p>All columns have comments!</p>';
    END IF;
    
    /************************************************************************************************************************/
    
    v_mail_body := v_mail_body || '<hr />';
    v_mail_body := v_mail_body || '<h2>Tables having columns that are not being added to tables audit log table</h2>';
    
    FOR record
        IN (  SELECT uob.object_name                         main_table_name,
                     SUBSTR (uob.object_name, 1, 26) || '_LOG' log_table_name
                FROM sys.user_objects uob
               WHERE     uob.object_type = 'TABLE'
                     AND uob.object_name NOT LIKE '%_LOG'
                     AND EXISTS
                             (SELECT *
                                FROM sys.user_objects uobin
                               WHERE     uobin.object_type = 'TABLE'
                                     AND uobin.object_name = SUBSTR (uob.object_name, 1, 26) || '_LOG')
            ORDER BY uob.object_name)
    LOOP
        FOR rec_main_table 
            IN (SELECT *
                  FROM sys.user_tab_columns utc
                 WHERE utc.table_name = record.main_table_name) 
        LOOP
            SELECT COUNT (*)
              INTO v_log_table_column_count
              FROM sys.user_tab_columns utc
             WHERE     utc.table_name = record.log_table_name
                   AND utc.column_name = rec_main_table.column_name;

            IF v_log_table_column_count = 0
            THEN
                v_mail_body := v_mail_body || 'Main table: ' || record.main_table_name || ', Log Table: ' || record.log_table_name || ', Column: ' || rec_main_table.column_name || '<BR />';
            END IF;
        END LOOP;
        
    END LOOP;
    
    IF v_mail_body NOT LIKE '%<BR />'
    THEN
        v_mail_body := v_mail_body || '<p>All tables and their audit log tables are aligned!</p>';
    END IF;
    
    /************************************************************************************************************************/
    
    v_mail_body := v_mail_body || '<hr />';
    v_mail_body := v_mail_body || '<h2>Tables having columns that are not being added to audit log trigger</h2>';
    
    FOR record
        IN (  SELECT uob.object_name                         main_table_name,
                     'TRG_' || SUBSTR (uob.object_name, 1, 26) trigger_name
                FROM sys.user_objects uob
               WHERE     uob.object_type = 'TABLE'
                     AND uob.object_name NOT LIKE '%_LOG'
                     AND EXISTS
                             (SELECT *
                                FROM sys.user_objects uobin
                               WHERE     uobin.object_type = 'TRIGGER'
                                     AND uobin.object_name = 'TRG_' || SUBSTR (uob.object_name, 1, 26))
            ORDER BY uob.object_name)
    LOOP
        FOR rec_main_table 
            IN (SELECT *
                  FROM sys.user_tab_columns utc
                 WHERE utc.table_name = record.main_table_name) 
        LOOP
            SELECT COUNT (*)
              INTO v_trigger_pure_column_count
              FROM sys.user_source src
             WHERE     src.type = 'TRIGGER'
                   AND src.name = record.trigger_name
                   AND UPPER(src.text) LIKE '%, ' || rec_main_table.column_name || '%';
            
            SELECT COUNT (*)
              INTO v_trigger_new_column_count
              FROM sys.user_source src
             WHERE     src.type = 'TRIGGER'
                   AND src.name = record.trigger_name
                   AND UPPER(src.text) LIKE '%, :NEW.' || rec_main_table.column_name || '%';
            
            SELECT COUNT (*)
              INTO v_trigger_old_column_count
              FROM sys.user_source src
             WHERE     src.type = 'TRIGGER'
                   AND src.name = record.trigger_name
                   AND UPPER(src.text) LIKE '%, :OLD.' || rec_main_table.column_name || '%';

            IF v_trigger_pure_column_count < 3 OR v_trigger_new_column_count < 2 OR v_trigger_old_column_count < 1
            THEN
                v_mail_body := v_mail_body || 'Main table: ' || record.main_table_name || ', Trigger Name: ' || record.trigger_name || ', Column: ' || rec_main_table.column_name || '<BR />';
            END IF;
        END LOOP;
        
    END LOOP;
    
    IF v_mail_body NOT LIKE '%<BR />'
    THEN
        v_mail_body := v_mail_body || '<p>All tables and their audit log triggers are aligned!</p>';
    END IF;
    
    /************************************************************************************************************************/

    SELECT prp.VALUE
      INTO v_mail_to
      FROM schema_name.properties prp
     WHERE key = 'db.mail.to.dataModelReport';

    SELECT prp.VALUE
      INTO v_mail_from
      FROM schema_name.properties prp
     WHERE key = 'db.mail.from';

    SELECT prp.VALUE
      INTO v_mail_source
      FROM schame_name.properties prp
     WHERE key = 'db.mail.environment';

    send_mail (p_mail_to        => v_mail_to,
               p_mail_from      => v_mail_from,
               p_subject        => 'schema_name Data Model Change Report',
               p_mail_source    => v_mail_source,
               p_message_body   => v_mail_body);
END;