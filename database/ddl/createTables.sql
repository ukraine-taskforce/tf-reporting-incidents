CREATE SCHEMA IF NOT EXISTS ugt;

create table ugt.user
(
    id            uuid not null
        constraint user_pk
            primary key,
    external_id   varchar(30),
    language_code varchar(10),
    score         integer,
    created_on    timestamp with time zone
);

create table ugt.incident
(
    id                 uuid                     not null
        constraint incident_pk
            primary key,
    incident_timestamp timestamp with time zone not null,
    incident_type      varchar                  not null,
    location_lat       varchar,
    location_long      varchar,
    distance           varchar(30),
    status             varchar(30)              not null,
    created_on         timestamp with time zone not null
);

create table ugt.incident_user
(
    user_id     uuid
        constraint incident_user___fk_user
            references ugt."user",
    incident_id uuid
        constraint incident_user___fk_incident
            references ugt.incident
);