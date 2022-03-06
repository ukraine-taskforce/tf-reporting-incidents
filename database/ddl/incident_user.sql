create table ugt.incident_user
(
    user_id     uuid
        constraint incident_user___fk_user
            references ugt."user",
    incident_id uuid
        constraint incident_user___fk_incident
            references ugt.incident
);