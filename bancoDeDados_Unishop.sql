
CREATE TABLE log_admin (
    id_log INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_admin INTEGER NOT NULL,
    acao VARCHAR(50) NOT NULL,
    entidade VARCHAR(20) NOT NULL,
    id_entidade INTEGER NOT NULL,
    data_acao TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_log_admin_usuario
        FOREIGN KEY (id_admin)
        REFERENCES usuario(id_usuario)
);
