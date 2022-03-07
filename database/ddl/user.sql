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