-- CRIANDO DATABASE E USANDO O DB
CREATE DATABASE yotte;
USE yotte;

-- CRIANDO A TABELA DE EMPRESA CLIENTE
CREATE TABLE empresa (
    id_empresa INT PRIMARY KEY IDENTITY,
    nome VARCHAR(45),
    nome_fantasia VARCHAR(45),
    cnpj CHAR(14),
    email VARCHAR(90) UNIQUE,
    senha VARCHAR(90)
);

-- SQLINES LICENSE FOR EVALUATION USE ONLY
CREATE TABLE tipo_usuario (
    id_tipo_usuario INT PRIMARY KEY IDENTITY,
    tipo INT CHECK (tipo IN (1, 2, 3))
);

-- INSERINDO OS TIPOS DE USUÁRIOS CADASTRADOS
INSERT INTO tipo_usuario (tipo) VALUES (1), (2), (3);

-- CRIANDO A TABELA DE USUÁRIO
CREATE TABLE usuario (
    id_usuario INT PRIMARY KEY IDENTITY,
    nome VARCHAR(45),
    email VARCHAR(45) UNIQUE,
    senha VARCHAR(45),
    area VARCHAR(45),
    cargo VARCHAR(45),
    fk_empresa INT,
    fk_tipo_usuario INT,
    FOREIGN KEY (fk_empresa) REFERENCES empresa(id_empresa),
    FOREIGN KEY (fk_tipo_usuario) REFERENCES tipo_usuario(id_tipo_usuario)
);

-- CRIANDO A TABELA DE TOKEN DE SEGURANÇA DO USUÁRIO
CREATE TABLE token (
    idtoken INT PRIMARY KEY IDENTITY,
    token VARCHAR(45) UNIQUE,
    data_criado DATETIME2(0) DEFAULT GETDATE(),
    fk_usuario INT,
    FOREIGN KEY (fk_usuario) REFERENCES usuario(id_usuario)
);

-- CRIANDO A TABELA DAS MÁQUINAS
CREATE TABLE maquina (
    id_maquina INT PRIMARY KEY IDENTITY,
    ip VARCHAR(45),
    so VARCHAR(45),
    modelo VARCHAR(45),
    fk_usuario INT,
    fk_token INT,
    FOREIGN KEY (fk_usuario) REFERENCES usuario(id_usuario),
    FOREIGN KEY (fk_token) REFERENCES token(idtoken)
);

-- CRIANDO A TABELA DE INFORMAÇÕES DE CADA TIPO DE COMPONENTE
CREATE TABLE info_componente (
    id_info INT PRIMARY KEY IDENTITY,
    qtd_cpu_logica INT,
    qtd_cpu_fisica INT,
    total FLOAT
);

-- CRIANDO A TABELA DE COMPONENTES DA MÁQUINA
CREATE TABLE componente (
    id_componente INT PRIMARY KEY IDENTITY,
    nome VARCHAR(45),
    parametro VARCHAR(20),
    fk_info INT,
    fk_maquina INT,
    FOREIGN KEY (fk_info) REFERENCES info_componente(id_info),
    FOREIGN KEY (fk_maquina) REFERENCES maquina(id_maquina)
);

-- CRIANDO A TABELA DE PARAMETROS DE COMPONENTES PARA O DISPARO DE ALERTAS
CREATE TABLE parametro_componente (
    id_parametro INT PRIMARY KEY IDENTITY,
    valor_minimo FLOAT,
    valor_maximo FLOAT,
    fk_componente INT,
    FOREIGN KEY (fk_componente) REFERENCES componente(id_componente)
);


-- CRIANDO A TABELA DE CAPTURA DE DADOS DE ACORDO COM OS COMPONENTES
CREATE TABLE dados_captura (
    id_dados_captura INT PRIMARY KEY IDENTITY,
    uso bigint,
    byte_leitura bigint,
    leituras int,
    byte_escrita bigint,
    escritas int,
    data_captura DATETIME2(0),
    desligada bit,
    frequencia FLOAT,
    fk_componente INT,
    FOREIGN KEY (fk_componente) REFERENCES componente(id_componente)
);


-- CRIANDO A TABELA DE JANELAS ABERTAS NA MÁQUINA
CREATE TABLE janela (
    id_janela INT PRIMARY KEY IDENTITY,
    pid INT,
    titulo VARCHAR(45),
    comando VARCHAR(45),
    localizacao VARCHAR(45),
    visivel BIT,
    fk_maquina INT,
    FOREIGN KEY (fk_maquina) REFERENCES maquina(id_maquina)
);

-- CRIANDO A TABELA DE PROCESSOS DA MÁQUINA
CREATE TABLE processo (
    id_processo INT PRIMARY KEY IDENTITY,
    pid INT,
    uso_cpu DECIMAL(5, 2),
    uso_memoria DECIMAL(5, 2),
    bytes_utilizados INT,
    fk_maquina INT,
    FOREIGN KEY (fk_maquina) REFERENCES maquina(id_maquina)
);

-- CRIANDO A TABELA DE ALERTAS
CREATE TABLE alerta (
id_alerta INT PRIMARY KEY IDENTITY,
descricao VARCHAR(90),
fk_dados_captura INT,
	FOREIGN KEY (fk_dados_captura) REFERENCES dados_captura(id_dados_captura)
);


DROP TRIGGER IF EXISTS verifica_alerta_expediente;


CREATE TRIGGER verifica_alerta_expediente
ON dados_captura
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @componente_nome VARCHAR(45);
    DECLARE @componente_uso BIGINT;
    DECLARE @porcentagem_uso DECIMAL(5, 2);
    DECLARE @parametro_componente VARCHAR(20);

    -- Criar tabela temporária para armazenar resultados do CTE
    CREATE TABLE #DadosCapturaCTE (
        componente_nome VARCHAR(45),
        usuario_nome VARCHAR(45),
        id_maquina INT,
        primeira_captura_dia DATETIME,
        ultima_captura_dia DATETIME,
        horario_logado_fora BIT
    );

    -- Inserir resultados do CTE na tabela temporária
    INSERT INTO #DadosCapturaCTE (componente_nome, usuario_nome, id_maquina, primeira_captura_dia, ultima_captura_dia, horario_logado_fora)
    SELECT
        c.nome AS componente_nome,
        u.nome AS usuario_nome,
        m.id_maquina,
        MIN(dc.data_captura) AS primeira_captura_dia,
        MAX(dc.data_captura) AS ultima_captura_dia,
        CASE
            WHEN DATEPART(HOUR, i.data_captura) < 7 OR DATEPART(HOUR, i.data_captura) > 19 THEN 1
            ELSE 0
        END AS horario_logado_fora
    FROM
        componente c
        JOIN maquina m ON c.fk_maquina = m.id_maquina
        JOIN usuario u ON m.fk_usuario = u.id_usuario
        JOIN dados_captura dc ON dc.fk_componente = c.id_componente
        JOIN inserted i ON dc.id_dados_captura = i.id_dados_captura
    WHERE
        c.id_componente = i.fk_componente
    GROUP BY
        c.nome, u.nome, m.id_maquina, i.data_captura;

    IF EXISTS (SELECT 1 FROM #DadosCapturaCTE WHERE horario_logado_fora = 1)
    BEGIN
        INSERT INTO alerta (descricao, fk_dados_captura)
        SELECT CONCAT('Usuário ', usuario_nome, ' logou fora do expediente na máquina ', id_maquina, '. Tempo de atividade: ', DATEDIFF(MINUTE, primeira_captura_dia, ultima_captura_dia), ' minutos.'), id_dados_captura
        FROM #DadosCapturaCTE
        WHERE horario_logado_fora = 1;
    END;

    -- Drop da tabela temporária
    DROP TABLE #DadosCapturaCTE;
END;

-- DADOS LOGIN DE EMPRESA
INSERT INTO empresa (nome, nome_fantasia, cnpj, email, senha)
VALUES ('jdbc', 'JDBC', '12345678901234', 'empresa@email.com', 'senha123'),
       ('Outra Empresa', 'Outra Fantasia', '56789012345678', 'outra@email.com', 'senha456');
       
-- DADOS LOGIN DE ADMINISTRADOR
INSERT INTO usuario (nome, email, senha, area, cargo, fk_empresa, fk_tipo_usuario)
VALUES 
	('brian', 'brian@.com.com', '1234', 'Engenharia', 'analista', 1, 2),
    ('lira', 'lira@.com.com', '1234', 'Engenharia', 'analista', 1, 3),
    ('Daniel', 'dan@.com.com', '1234', 'Engenharia', 'analista', 1, 3),
    ('Pimentel', 'pi@.com.com', '1234', 'Engenharia', 'analista', 2, 2),
    ('Lorena', 'lo@.com.com', '1234', 'Engenharia', 'analista', 2, 3),
    ('Julia', 'ju@.com.com', '1234', 'Engenharia', 'analista', 2, 3);


-- INSERT DOS TOKENS DE SEGURANÇA
INSERT INTO token (token, fk_usuario)
VALUES ('12345', 1),
       ('54321', 1),
       ('94131', 4),
       ('35412', 4);
       

-- INSERT DE INFORMAÇÕES DA MÁQUINA
INSERT INTO maquina (ip, so, modelo, fk_usuario, fk_token)
VALUES
	('89042509348', 'Pop Os!', 'Modelo do bem', 2, 1),
	('89042509348', 'Pop Os!', 'Modelo do bem', 3, 2),
	('19042509222', 'Linux Mint', 'Modelo do bem', 5, 3),
	('79042509111', 'Linux Mint', 'Modelo do bem', 6, 4);
    

-- INSERT DE INFORMAÇÕES DOS COMPONENTES
INSERT INTO info_componente (qtd_cpu_logica, qtd_cpu_fisica, total)
VALUES 
    (null, null, 8123420000), -- maquina01 
    (2, 2, null), -- maquina01
    (null, null, 1073740000), -- maquina01
    (null, null, 8123420000), -- maquina02
    (2, 2, null), -- maquina02
    (null, null, 1073740000), -- maquina02
    (null, null, 8123420000), -- maquina03
    (2, 2, null), -- maquina03
    (null, null, 1073740000), -- maquina03
    (null, null, 8123420000), -- maquina04
    (2, 2, null), -- maquina04
    (null, null, 1073740000); -- maquina04
    

-- INSERT DOS TIPOS DE COMPONENTES

INSERT INTO componente (nome, parametro, fk_info, fk_maquina)
VALUES 
    ('memoria', 'bytes', 1, 1),
    ('cpu', '%', 2, 1),
    ('disco', 'bytes', 3, 1),
    ('memoria', 'bytes', 4, 2),
    ('cpu', '%', 5, 2),
    ('disco', 'bytes', 6, 2),
    ('memoria', 'bytes', 7, 3),
    ('cpu', '%', 8, 3),
    ('disco', 'bytes', 9, 3),
    ('memoria', 'bytes', 10, 4),
    ('cpu', '%', 11, 4),
    ('disco', 'bytes', 12, 4);

-- INSERT DOS PARAMETROS
INSERT INTO parametro_componente (valor_minimo, valor_maximo, fk_componente)
VALUES 
(80, 50, 1),
(80, 30, 2),
(80, 30, 3),
(80, 30, 4),
(60, 20, 5),
(60, 20, 6),
(60, 20, 7),
(60, 20, 8),
(70, 20, 9),
(70, 20, 10),
(70, 20, 11),
(70, 20, 12);


-- INSERT NA TABELA dados_captura

INSERT INTO dados_captura (uso, byte_leitura, leituras, byte_escrita,
 escritas, data_captura, desligada, frequencia, fk_componente)
VALUES 
    (5579563008, null, null, null, null, GETDATE(), 0, 18000000, 1),
    (14, null, null, null, null, GETDATE(), 0, null, 2),
    (null, 1536, 1300, 768, 900, GETDATE(), 0, null, 3),
    (5579563008, null, null, null, null, GETDATE(), 0, 1800000, 4),
    (14, null, null, null, null, GETDATE(), 0, null, 5),
    (null, 1792, 1400, 896, 1000, GETDATE(), 0, null, 6),
    (5579563008, null, null, null, null, GETDATE(), 0, 1800000000, 7),
    (45, null, null, null, null, GETDATE(), 0, null, 8),
    (null, 4096, 2500, 3072, 2200, GETDATE(), 0, null, 9),
    (5579563008, null, null, null, null, GETDATE(), 0, 1800000000, 10),
    (52, null, null, null, null, GETDATE(), 0, null, 11),
    (null, 4096, 2500, 3072, 2200, GETDATE(), 0, null, 12),
    (5579563008, null, null, null, null, GETDATE(), 0, 1800000000, 1),
    (25, null, null, null, null, GETDATE(), 0, null, 2),
    (null, 4096, 2500, 3072, 2200, GETDATE(), 0, null, 3),
    (5579563008, null, null, null, null, GETDATE(), 0, 1800000000, 4),
    (50, null, null, null, null, GETDATE(), 0, null, 5),
    (null, 4096, 2500, 3072, 2200, GETDATE(), 0, null, 6),
    (5579563008, null, null, null, null, GETDATE(), 0, 1800000000, 7),
    (19, null, null, null, null, GETDATE(), 0, null, 8),
    (null, 4096, 2500, 3072, 2200, GETDATE(), 0, null, 9),
    (5579563008, null, null, null, null, GETDATE(), 0, 1800000000, 10),
    (37, null, null, null, null, GETDATE(), 0, null, 11),
    (null, 4096, 2500, 3072, 2200, GETDATE(), 0, null, 12);

-- SELECT DOS ALERTAS
select * from alerta;

-- VER O TEMPO DE INATIVIDADE DAS MÁQUINAS
WITH DiferencaCapturas AS (
    SELECT
        id_maquina,
        data_captura,
        empresa.nome as nomeEmpresa,
        usuario.nome as nomeUsuario,
        id_usuario,
        empresa.id_empresa,
        LAG(data_captura) OVER (PARTITION BY id_maquina ORDER BY data_captura) AS data_captura_anterior,
        desligada
    FROM dados_captura
    JOIN componente ON dados_captura.fk_componente = componente.id_componente
    JOIN maquina ON componente.fk_maquina = maquina.id_maquina
    JOIN usuario on maquina.fk_usuario = usuario.id_usuario
    JOIN empresa on usuario.fk_empresa = empresa.id_empresa
    WHERE data_captura >= DATEADD(DAY, -7, CONVERT(DATE, GETDATE()))
)
SELECT
    id_maquina,
    DATEDIFF(HOUR, MAX(data_captura_anterior), MIN(data_captura)) AS tempo_inatividade_horas
FROM DiferencaCapturas
WHERE id_empresa = 1
    AND id_usuario = 1
GROUP BY id_maquina
ORDER BY tempo_inatividade_horas ASC;

-- SELECT PARAPEGAR O NÚMERO DE ALERTAS DE CADA MÁQUINA, COM ADM E FUNCIONÁRIOS DA EMPRESA
SELECT
    funcionario.id_usuario AS id_func,
    COUNT(alerta.id_alerta) AS count_alertas,
    admin.nome AS admins,
    funcionario.nome AS funcionario
FROM 
    usuario AS admin 
JOIN 
    token ON admin.id_usuario = token.fk_usuario
JOIN
    maquina ON token.idtoken = maquina.fk_token
JOIN 
    usuario AS funcionario ON funcionario.id_usuario = maquina.fk_usuario
JOIN 
    dados_captura ON maquina.id_maquina = dados_captura.fk_componente -- Substitua maquina.fk_usuario pelo campo correto
JOIN 
    alerta ON dados_captura.id_dados_captura = alerta.fk_dados_captura
JOIN 
    empresa ON funcionario.fk_empresa = empresa.id_empresa
WHERE 
    admin.id_usuario = 1 AND empresa.id_empresa = 1
GROUP BY 
    funcionario.id_usuario, admin.nome, funcionario.nome;
 
-- VER AS MÁQUINAS QUE TIVERAM CAPTURAS FORA DO HORÁRIO DE EXPEDIENTE
WITH DiferencaCapturas AS (
    SELECT
        maquina.id_maquina,
        usuario.nome as nome_usuario,
        usuario.id_usuario,
        MAX(dados_captura.data_captura) as ultima_captura_dia,
        MIN(dados_captura.data_captura) AS primeira_captura_dia,
        MAX(CASE WHEN DATEPART(HOUR, dados_captura.data_captura) < 7 OR DATEPART(HOUR, dados_captura.data_captura) > 19 THEN 1 ELSE 0 END) AS aviso
    FROM dados_captura
    JOIN componente ON dados_captura.fk_componente = componente.id_componente
    JOIN maquina ON componente.fk_maquina = maquina.id_maquina
    JOIN usuario ON maquina.fk_usuario = usuario.id_usuario
    WHERE CONVERT(DATE, dados_captura.data_captura) = CONVERT(DATE, GETDATE()) -- Dados do dia de hoje
    GROUP BY maquina.id_maquina, usuario.nome, usuario.id_usuario
)
SELECT
    id_maquina,
    nome_usuario,
    SUM(CASE WHEN aviso = 1 THEN DATEDIFF(MINUTE, primeira_captura_dia, ultima_captura_dia) ELSE 0 END) AS tempo_fora_expediente_minutos
FROM DiferencaCapturas
GROUP BY id_maquina, nome_usuario
ORDER BY tempo_fora_expediente_minutos DESC;

-- SELECT DE ALERTAS DE ACORDO COM O COMPONENTE DA MÁQUINA
SELECT
    maquina.id_maquina,
    usuario.nome,
    SUM(CASE WHEN componente.nome = 'CPU' THEN 1 ELSE 0 END) AS count_alerta_cpu,
    SUM(CASE WHEN componente.nome = 'RAM' THEN 1 ELSE 0 END) AS count_alerta_ram,
    SUM(CASE WHEN componente.nome = 'HD' THEN 1 ELSE 0 END) AS count_alerta_hd
FROM
    maquina
JOIN usuario ON maquina.fk_usuario = usuario.id_usuario
JOIN empresa ON usuario.fk_empresa = empresa.id_empresa
LEFT JOIN componente ON maquina.id_maquina = componente.fk_maquina
LEFT JOIN dados_captura ON componente.id_componente = dados_captura.fk_componente
LEFT JOIN alerta ON dados_captura.id_dados_captura = alerta.fk_dados_captura
WHERE
    empresa.id_empresa = 2
    AND usuario.id_usuario = 6
GROUP BY
    maquina.id_maquina, usuario.nome;

-- VER A LISTA DE USUÁRIOS CADASTRADOS
select * from usuario;

-- VER A LISTA DE MÁQUINAS
select * from maquina;