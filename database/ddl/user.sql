create table ugt."user"
(
    id            uuid
        constraint user_pk
            primary key,
    external_id   varchar(30),
    language_code varchar(10),
    score         INT,
    created_on    timestamp
);
