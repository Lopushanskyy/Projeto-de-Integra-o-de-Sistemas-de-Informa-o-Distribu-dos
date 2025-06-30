-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: May 20, 2025 at 02:52 PM
-- Server version: 10.4.32-MariaDB
-- PHP Version: 8.0.30

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `labirinto`
--

DELIMITER $$
--
-- Procedures
--
CREATE DEFINER=`root`@`localhost` PROCEDURE `AlterarDescricaoJogo` (IN `p_idJogo` INT, IN `p_novaDescricao` TEXT)   BEGIN
    DECLARE v_idJogador INT;
    DECLARE v_nome VARCHAR(100);

    -- Extrai apenas o nome do user sem o host (ex: 'joao@localhost' → 'joao')
    SET v_nome = SUBSTRING_INDEX(USER(), '@', 1);

    -- Busca o ID do utilizador com esse nome
    SELECT ID INTO v_idJogador
    FROM utilizador
    WHERE Nome = v_nome
    LIMIT 1;

    -- Verifica se é o dono do jogo
    IF EXISTS (
        SELECT 1 FROM jogo
        WHERE IDJogo = p_idJogo AND JogadorID = v_idJogador
    ) THEN
        UPDATE jogo
        SET Descricao = p_novaDescricao
        WHERE IDJogo = p_idJogo;
    ELSE
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Permissão negada: utilizador não é dono deste jogo.';
    END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `CriarJogo` (IN `p_descricao` VARCHAR(255), OUT `p_idJogo` INT)   BEGIN
    DECLARE v_nome VARCHAR(100);
    DECLARE v_idJogador INT;

    -- Obter o nome do utilizador logado (sem o host)
    SET v_nome = SUBSTRING_INDEX(USER(), '@', 1);

    -- Obter o ID do utilizador com esse nome
    SELECT ID INTO v_idJogador
    FROM utilizador
    WHERE Nome = v_nome
    LIMIT 1;

    -- Verifica se encontrou o utilizador
    IF v_idJogador IS NOT NULL THEN
        INSERT INTO jogo (Descricao, JogadorID, Estado)
        VALUES (p_descricao, v_idJogador, 1);

        -- Retorna o ID do jogo recém-criado
        SET p_idJogo = LAST_INSERT_ID();
    ELSE
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Utilizador não encontrado.';
    END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `CriarJogoAdmin` (IN `p_JogadorID` INT, IN `p_Descricao` TEXT, IN `p_Estado` INT)   BEGIN
    -- Verifica se o jogador existe na tabela utilizador
    DECLARE jogador_existente INT;

    SELECT COUNT(*) INTO jogador_existente
    FROM utilizador
    WHERE ID = p_JogadorID;

    -- Se o jogador não existir, retorna um erro
    IF jogador_existente = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Jogador não encontrado';
    ELSE
        -- Insere o novo jogo na tabela jogo com pontuação inicial 0
        INSERT INTO jogo (Descricao, JogadorID, Estado, Pontuacao)
        VALUES (p_Descricao, p_JogadorID, p_Estado, 0);
    END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `CriarUtilizador` (IN `p_nome` VARCHAR(100), IN `p_password` VARCHAR(100))   BEGIN
    -- Criar utilizador MariaDB
SET @sql = CONCAT('CREATE USER \'', p_nome, '\'@\'localhost\' IDENTIFIED BY \'', p_password, '\';');

    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    -- Conceder permissão para executar as stored procedures
    SET @sql = CONCAT('GRANT EXECUTE ON PROCEDURE `AlterarDescricaoJogo` TO \'', p_nome, '\';');
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SET @sql = CONCAT('GRANT EXECUTE ON PROCEDURE `EditarUtilizador` TO \'', p_nome, '\';');
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    
     SET @sql = CONCAT('GRANT EXECUTE ON PROCEDURE `CriarJogo` TO \'', p_nome, '\';');
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    -- Criar a VIEW para esse utilizador (apenas jogos dele)
    SET @sql = CONCAT('CREATE OR REPLACE VIEW vw_jogos_', p_nome, ' AS
    SELECT * FROM jogo
    WHERE JogadorID = (SELECT ID FROM utilizador WHERE Nome = \'', p_nome, '\');');
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    -- Conceder permissões de SELECT, UPDATE, DELETE na VIEW
    SET @sql = CONCAT('GRANT SELECT, UPDATE, DELETE ON vw_jogos_', p_nome, ' TO \'', p_nome, '\';');
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    -- Conceder permissões de SELECT, INSERT, UPDATE, DELETE na tabela jogo
    SET @sql = CONCAT('GRANT INSERT, UPDATE ON jogo TO \'', p_nome, '\'@\'localhost\';');
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    -- Conceder permissões de UPDATE na tabela utilizador
    SET @sql = CONCAT('GRANT UPDATE ON utilizador TO \'', p_nome, '\'@\'localhost\';');
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    -- Inserir o novo utilizador na tabela da aplicação
    INSERT INTO Utilizador (Nome, Telemovel, Email, Tipo)
    VALUES (p_nome, NULL, NULL, 'U');
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `EditarUtilizador` (IN `p_telemovel` VARCHAR(12), IN `p_email` VARCHAR(50))   BEGIN
    DECLARE v_nome VARCHAR(100);
    DECLARE v_idUtilizador INT;

    -- Obter o nome do utilizador logado (sem o host)
    SET v_nome = SUBSTRING_INDEX(USER(), '@', 1);

    -- Obter o ID do utilizador com esse nome
    SELECT ID INTO v_idUtilizador
    FROM utilizador
    WHERE Nome = v_nome
    LIMIT 1;

    -- Verificar se encontrou o utilizador
    IF v_idUtilizador IS NOT NULL THEN
        UPDATE utilizador
        SET Telemovel = p_telemovel,
            Email = p_email
        WHERE ID = v_idUtilizador;
    ELSE
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Utilizador não encontrado.';
    END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `LimparTabelas` ()   BEGIN
    DELETE FROM medicoespassagens;
    DELETE FROM mensagens;
    DELETE FROM ocupacaolabirinto;
    DELETE FROM sound;
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `jogo`
--

CREATE TABLE `jogo` (
  `IDJogo` int(11) NOT NULL,
  `Descricao` text DEFAULT NULL,
  `JogadorID` int(11) DEFAULT NULL,
  `DataHoraInicio` timestamp NULL DEFAULT current_timestamp(),
  `Estado` int(11) DEFAULT NULL,
  `Pontuacao` float DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `jogo`
--

INSERT INTO `jogo` (`IDJogo`, `Descricao`, `JogadorID`, `DataHoraInicio`, `Estado`, `Pontuacao`) VALUES
(124, 'olaola', 44, '2025-05-08 17:17:30', 1, 0),
(125, 'jogogogo', 44, '2025-05-08 17:24:52', 1, 0),
(126, 'oioi', 44, '2025-05-08 17:36:01', 1, 0),
(127, 'asdad', 44, '2025-05-08 17:47:23', 1, 0),
(128, '.', 44, '2025-05-20 10:20:45', 1, 0),
(129, '.', 44, '2025-05-20 10:39:14', 1, 0),
(130, '.', 44, '2025-05-20 10:59:23', 1, 0),
(131, '1', 44, '2025-05-20 11:36:27', 1, 0),
(132, '1', 44, '2025-05-20 12:02:48', 1, 0),
(133, '1', 44, '2025-05-20 12:07:43', 1, 0),
(134, '11', 44, '2025-05-20 12:28:14', 1, 0),
(135, '1', 44, '2025-05-20 12:39:33', 1, 0),
(136, '1', 44, '2025-05-20 12:45:18', 1, 12);

--
-- Triggers `jogo`
--
DELIMITER $$
CREATE TRIGGER `cria_salas_jogo` AFTER INSERT ON `jogo` FOR EACH ROW BEGIN
    DECLARE i INT DEFAULT 1;
    WHILE i <= 10 DO
        INSERT INTO ocupacaolabirinto (Sala, IDJogo, numeromarsamisodd, numeromarsamiseven, tentativas)
        VALUES (i, NEW.IDJogo, 0, 0, 0);
        SET i = i + 1;
    END WHILE;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `medicoespassagens`
--

CREATE TABLE `medicoespassagens` (
  `IDMedicao` int(11) NOT NULL,
  `Hora` timestamp NULL DEFAULT current_timestamp(),
  `SalaOrigem` int(11) DEFAULT NULL,
  `SalaDestino` int(11) DEFAULT NULL,
  `Marsami` int(11) DEFAULT NULL,
  `Status` int(11) DEFAULT NULL,
  `IDJogo` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `medicoespassagens`
--

INSERT INTO `medicoespassagens` (`IDMedicao`, `Hora`, `SalaOrigem`, `SalaDestino`, `Marsami`, `Status`, `IDJogo`) VALUES
(7182, '2025-05-20 12:45:47', 0, 2, 1, 1, 136),
(7183, '2025-05-20 12:45:50', 0, 6, 2, 1, 136),
(7184, '2025-05-20 12:45:53', 0, 10, 3, 1, 136),
(7185, '2025-05-20 12:45:55', 0, 3, 4, 1, 136),
(7186, '2025-05-20 12:45:57', 0, 2, 5, 1, 136),
(7187, '2025-05-20 12:45:59', 0, 10, 6, 1, 136),
(7188, '2025-05-20 12:46:02', 0, 1, 7, 1, 136),
(7189, '2025-05-20 12:46:04', 0, 1, 8, 1, 136),
(7190, '2025-05-20 12:46:06', 0, 10, 9, 1, 136),
(7191, '2025-05-20 12:46:08', 0, 9, 10, 1, 136),
(7192, '2025-05-20 12:46:11', 0, 10, 11, 1, 136),
(7193, '2025-05-20 12:46:13', 0, 7, 12, 1, 136),
(7194, '2025-05-20 12:46:15', 0, 8, 13, 1, 136),
(7195, '2025-05-20 12:46:17', 0, 10, 14, 1, 136),
(7196, '2025-05-20 12:46:20', 0, 7, 15, 1, 136),
(7197, '2025-05-20 12:46:23', 0, 3, 16, 1, 136),
(7198, '2025-05-20 12:46:25', 0, 7, 17, 1, 136),
(7199, '2025-05-20 12:46:27', 0, 5, 18, 1, 136),
(7200, '2025-05-20 12:46:29', 0, 8, 19, 1, 136),
(7201, '2025-05-20 12:46:31', 0, 1, 20, 1, 136),
(7202, '2025-05-20 12:46:33', 0, 1, 21, 1, 136),
(7203, '2025-05-20 12:46:36', 0, 8, 22, 1, 136),
(7204, '2025-05-20 12:46:38', 0, 10, 23, 1, 136),
(7205, '2025-05-20 12:46:40', 0, 7, 24, 1, 136),
(7206, '2025-05-20 12:46:42', 0, 9, 25, 1, 136),
(7207, '2025-05-20 12:46:44', 0, 1, 26, 1, 136),
(7208, '2025-05-20 12:46:46', 0, 1, 27, 1, 136),
(7209, '2025-05-20 12:46:49', 0, 5, 28, 1, 136),
(7210, '2025-05-20 12:46:52', 0, 3, 29, 1, 136),
(7211, '2025-05-20 12:46:54', 0, 4, 30, 1, 136),
(7212, '2025-05-20 12:46:56', 5, 7, 28, 1, 136),
(7213, '2025-05-20 12:46:59', 8, 10, 22, 1, 136),
(7214, '2025-05-20 12:47:02', 7, 5, 12, 1, 136),
(7215, '2025-05-20 12:47:05', 2, 5, 5, 1, 136),
(7216, '2025-05-20 12:47:09', 1, 3, 7, 1, 136),
(7217, '2025-05-20 12:47:12', 5, 7, 5, 1, 136),
(7218, '2025-05-20 12:47:14', 9, 7, 25, 1, 136),
(7219, '2025-05-20 12:47:18', 1, 3, 20, 1, 136),
(7220, '2025-05-20 12:47:21', 10, 1, 9, 1, 136),
(7221, '2025-05-20 12:47:25', 8, 10, 19, 1, 136),
(7222, '2025-05-20 12:47:28', 3, 2, 7, 1, 136),
(7223, '2025-05-20 12:47:32', 8, 2, 27, 1, 136),
(7224, '2025-05-20 12:48:07', 3, 2, 29, 1, 136),
(7225, '2025-05-20 12:48:10', 7, 5, 28, 1, 136),
(7226, '2025-05-20 12:48:15', 7, 5, 5, 1, 136),
(7227, '2025-05-20 12:48:18', 10, 1, 23, 1, 136),
(7228, '2025-05-20 12:48:21', 10, 1, 14, 1, 136),
(7229, '2025-05-20 12:48:23', 5, 7, 5, 1, 136),
(7230, '2025-05-20 12:48:28', 1, 3, 8, 1, 136),
(7231, '2025-05-20 12:48:31', 10, 1, 11, 1, 136),
(7232, '2025-05-20 12:48:34', 3, 2, 8, 1, 136),
(7233, '2025-05-20 12:48:37', 1, 3, 11, 1, 136),
(7234, '2025-05-20 12:48:41', 10, 1, 3, 1, 136),
(7235, '2025-05-20 12:49:10', 0, 0, 1, 2, 136),
(7236, '2025-05-20 12:49:11', 0, 0, 1, 0, 136),
(7237, '2025-05-20 12:49:14', 0, 0, 2, 2, 136),
(7238, '2025-05-20 12:49:15', 0, 0, 2, 0, 136),
(7239, '2025-05-20 12:49:17', 0, 0, 3, 2, 136),
(7240, '2025-05-20 12:49:18', 0, 0, 3, 0, 136),
(7241, '2025-05-20 12:49:20', 0, 0, 5, 2, 136),
(7242, '2025-05-20 12:49:21', 0, 0, 5, 0, 136),
(7243, '2025-05-20 12:49:23', 0, 0, 4, 2, 136),
(7244, '2025-05-20 12:49:24', 0, 0, 4, 0, 136),
(7245, '2025-05-20 12:49:26', 0, 0, 6, 2, 136),
(7246, '2025-05-20 12:49:27', 0, 0, 6, 0, 136),
(7247, '2025-05-20 12:49:29', 1, 3, 27, 1, 136),
(7248, '2025-05-20 12:49:32', 8, 9, 13, 1, 136),
(7249, '2025-05-20 12:49:34', 0, 0, 7, 2, 136),
(7250, '2025-05-20 12:49:35', 0, 0, 7, 0, 136),
(7251, '2025-05-20 12:49:36', 0, 0, 10, 2, 136),
(7252, '2025-05-20 12:49:37', 0, 0, 10, 0, 136),
(7253, '2025-05-20 12:49:39', 7, 5, 25, 1, 136),
(7254, '2025-05-20 12:49:41', 0, 0, 11, 2, 136),
(7255, '2025-05-20 12:49:42', 0, 0, 11, 0, 136),
(7256, '2025-05-20 12:49:47', 7, 5, 24, 1, 136),
(7257, '2025-05-20 12:49:50', 5, 7, 30, 1, 136),
(7258, '2025-05-20 12:49:59', 0, 0, 17, 2, 136),
(7259, '2025-05-20 12:50:01', 0, 0, 8, 2, 136),
(7260, '2025-05-20 12:50:02', 0, 0, 8, 0, 136),
(7261, '2025-05-20 12:50:03', 0, 0, 19, 2, 136),
(7262, '2025-05-20 12:50:04', 0, 0, 19, 0, 136),
(7263, '2025-05-20 12:50:05', 0, 0, 23, 2, 136),
(7264, '2025-05-20 12:50:06', 0, 0, 23, 0, 136),
(7265, '2025-05-20 12:50:07', 0, 0, 13, 2, 136),
(7266, '2025-05-20 12:50:08', 0, 0, 13, 0, 136),
(7267, '2025-05-20 12:50:09', 0, 0, 18, 2, 136),
(7268, '2025-05-20 12:50:10', 0, 0, 18, 0, 136),
(7269, '2025-05-20 12:50:12', 0, 0, 21, 2, 136),
(7270, '2025-05-20 12:50:13', 0, 0, 21, 0, 136),
(7271, '2025-05-20 12:50:15', 0, 0, 25, 2, 136),
(7272, '2025-05-20 12:50:16', 0, 0, 25, 0, 136),
(7273, '2025-05-20 12:50:18', 0, 0, 26, 2, 136),
(7274, '2025-05-20 12:50:19', 0, 0, 26, 0, 136),
(7275, '2025-05-20 12:50:22', 0, 0, 28, 2, 136),
(7276, '2025-05-20 12:50:23', 0, 0, 28, 0, 136),
(7277, '2025-05-20 12:50:25', 0, 0, 29, 2, 136),
(7278, '2025-05-20 12:50:26', 0, 0, 29, 0, 136);

--
-- Triggers `medicoespassagens`
--
DELIMITER $$
CREATE TRIGGER `atualizar_ocupacao_labirinto` AFTER INSERT ON `medicoespassagens` FOR EACH ROW BEGIN
    DECLARE origem INT;
    DECLARE destino INT;
    DECLARE marsami INT;
    DECLARE jogo_id INT;

    SET origem = NEW.SalaOrigem;
    SET destino = NEW.SalaDestino;
    SET marsami = NEW.Marsami;
    SET jogo_id = NEW.IDJogo;

    -- Atualiza a sala de origem (decrementa Marsami)
    IF origem <> 0 THEN
        IF MOD(marsami, 2) = 1 THEN
            -- Marsami ímpar
            UPDATE ocupacaolabirinto
            SET NumeroMarsamisOdd = GREATEST(NumeroMarsamisOdd - 1, 0)
            WHERE Sala = origem AND IDJogo = jogo_id;
        ELSE
            -- Marsami par
            UPDATE ocupacaolabirinto
            SET NumeroMarsamisEven = GREATEST(NumeroMarsamisEven - 1, 0)
            WHERE Sala = origem AND IDJogo = jogo_id;
        END IF;
    END IF;

    -- Atualiza a sala de destino (incrementa Marsami)
    IF destino <> 0 THEN
        IF MOD(marsami, 2) = 1 THEN
            -- Marsami ímpar
            UPDATE ocupacaolabirinto
            SET NumeroMarsamisOdd = NumeroMarsamisOdd + 1
            WHERE Sala = destino AND IDJogo = jogo_id;
        ELSE
            -- Marsami par
            UPDATE ocupacaolabirinto
            SET NumeroMarsamisEven = NumeroMarsamisEven + 1
            WHERE Sala = destino AND IDJogo = jogo_id;
        END IF;
    END IF;

END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `mensagens`
--

CREATE TABLE `mensagens` (
  `ID` int(11) NOT NULL,
  `Hora` timestamp NULL DEFAULT current_timestamp(),
  `Sala` int(11) DEFAULT NULL,
  `Sensor` int(11) DEFAULT NULL,
  `Leitura` double DEFAULT NULL,
  `TipoAlerta` varchar(50) DEFAULT NULL,
  `Msg` varchar(100) DEFAULT NULL,
  `HoraEscrita` timestamp NULL DEFAULT NULL,
  `atuadorAcionado` tinyint(1) DEFAULT 0,
  `IDJogo` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `mensagens`
--

INSERT INTO `mensagens` (`ID`, `Hora`, `Sala`, `Sensor`, `Leitura`, `TipoAlerta`, `Msg`, `HoraEscrita`, `atuadorAcionado`, `IDJogo`) VALUES
(798, '2025-05-20 12:45:59', 10, 1, 0, 'movimento', 'ativar gatilho', '2025-05-20 12:45:59', 1, 136),
(799, '2025-05-20 12:46:04', 1, 1, 0, 'movimento', 'ativar gatilho', '2025-05-20 12:46:04', 1, 136),
(800, '2025-05-20 12:46:20', 7, 1, 0, 'movimento', 'ativar gatilho', '2025-05-20 12:46:20', 1, 136),
(801, '2025-05-20 12:46:33', 1, 1, 0, 'movimento', 'ativar gatilho', '2025-05-20 12:46:33', 1, 136),
(802, '2025-05-20 12:46:40', 7, 1, 0, 'movimento', 'ativar gatilho', '2025-05-20 12:46:40', 1, 136),
(803, '2025-05-20 12:46:42', 9, 1, 0, 'movimento', 'ativar gatilho', '2025-05-20 12:46:42', 1, 136),
(804, '2025-05-20 12:46:46', 1, 1, 0, 'movimento', 'ativar gatilho', '2025-05-20 12:46:46', 1, 136),
(805, '2025-05-20 12:46:56', NULL, 2, 19.542821395042193, 'sound', 'abrir portas', '2025-05-20 12:46:57', 1, 136),
(806, '2025-05-20 12:47:02', 7, 1, 0, 'movimento', 'ativar gatilho', '2025-05-20 12:47:02', 1, 136),
(807, '2025-05-20 12:47:02', NULL, 2, 19.7, 'sound', 'abrir portas', '2025-05-20 12:47:03', 1, 136),
(808, '2025-05-20 12:47:09', 3, 1, 0, 'movimento', 'ativar gatilho', '2025-05-20 12:47:09', 1, 136),
(809, '2025-05-20 12:47:21', 10, 1, 0, 'movimento', 'ativar gatilho', '2025-05-20 12:47:21', 1, 136),
(810, '0000-00-00 00:00:00', NULL, 2, 21.03333333333333, 'sound', 'fechar portas', '2025-05-20 12:47:29', 1, 136),
(811, '2025-05-20 12:47:35', NULL, 2, 21.2, 'sound', 'fechar portas', '2025-05-20 12:47:35', 1, 136),
(812, '2025-05-20 12:47:41', NULL, 2, 21.2, 'sound', 'fechar portas', '2025-05-20 12:47:41', 1, 136),
(813, '2025-05-20 12:47:46', NULL, 2, 21.03333333333333, 'sound', 'fechar portas', '2025-05-20 12:47:47', 1, 136),
(814, '2025-05-20 12:48:06', NULL, 2, 19.915810536924145, 'sound', 'abrir portas', '2025-05-20 12:48:06', 1, 136),
(815, '2025-05-20 12:48:16', NULL, 2, 19.883547686489376, 'sound', 'abrir portas', '2025-05-20 12:48:17', 1, 136),
(816, '2025-05-20 12:48:18', 10, 1, 0, 'movimento', 'ativar gatilho', '2025-05-20 12:48:18', 1, 136),
(817, '2025-05-20 12:48:39', NULL, 2, 21.205250169542097, 'sound', 'fechar portas', '2025-05-20 12:48:40', 1, 136),
(818, '2025-05-20 12:48:46', NULL, 2, 21.2, 'sound', 'fechar portas', '2025-05-20 12:48:46', 1, 136),
(819, '2025-05-20 12:48:51', NULL, 2, 21.2, 'sound', 'fechar portas', '2025-05-20 12:48:52', 1, 136),
(820, '2025-05-20 12:48:57', NULL, 2, 21.11531345553466, 'sound', 'fechar portas', '2025-05-20 12:48:58', 1, 136),
(821, '2025-05-20 12:49:21', NULL, 2, 19.866666666666667, 'sound', 'abrir portas', '2025-05-20 12:49:25', 1, 136),
(822, '2025-05-20 12:49:27', NULL, 2, 19.7, 'sound', 'abrir portas', '2025-05-20 12:49:31', 1, 136),
(823, '2025-05-20 12:49:32', 9, 1, 0, 'movimento', 'ativar gatilho', '2025-05-20 12:49:32', 1, 136),
(824, '2025-05-20 12:49:32', NULL, 2, 19.7, 'sound', 'abrir portas', '2025-05-20 12:49:38', 1, 136),
(825, '2025-05-20 12:49:56', NULL, 2, 21.171232860336055, 'sound', 'fechar portas', '2025-05-20 12:49:57', 1, 136),
(826, '2025-05-20 12:50:00', NULL, 2, 21.03333333333333, 'sound', 'fechar portas', '2025-05-20 12:50:05', 1, 136),
(827, '2025-05-20 12:50:01', NULL, 2, 21.03333333333333, 'sound', 'fechar portas', '2025-05-20 12:50:11', 1, 136),
(828, '2025-05-20 12:50:04', NULL, 2, 21.03333333333333, 'sound', 'fechar portas', '2025-05-20 12:50:17', 1, 136),
(829, '2025-05-20 12:50:11', NULL, 2, 21.034265480096547, 'sound', 'fechar portas', '2025-05-20 12:50:23', 1, 136),
(830, '2025-05-20 12:50:36', NULL, 2, 19.866666666666667, 'sound', 'abrir portas', '2025-05-20 12:50:37', 1, 136),
(831, '2025-05-20 12:50:42', NULL, 2, 19.7, 'sound', 'abrir portas', '2025-05-20 12:50:43', 1, 136);

-- --------------------------------------------------------

--
-- Table structure for table `ocupacaolabirinto`
--

CREATE TABLE `ocupacaolabirinto` (
  `Sala` int(11) NOT NULL,
  `IDJogo` int(11) NOT NULL,
  `NumeroMarsamisOdd` int(11) DEFAULT NULL,
  `NumeroMarsamisEven` int(11) DEFAULT NULL,
  `tentativas` int(11) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `ocupacaolabirinto`
--

INSERT INTO `ocupacaolabirinto` (`Sala`, `IDJogo`, `NumeroMarsamisOdd`, `NumeroMarsamisEven`, `tentativas`) VALUES
(1, 136, 4, 2, 3),
(2, 136, 4, 1, 0),
(3, 136, 2, 3, 1),
(4, 136, 0, 1, 0),
(5, 136, 1, 3, 0),
(6, 136, 0, 1, 0),
(7, 136, 3, 1, 3),
(8, 136, 0, 0, 0),
(9, 136, 1, 1, 2),
(10, 136, 1, 2, 3);

--
-- Triggers `ocupacaolabirinto`
--
DELIMITER $$
CREATE TRIGGER `trigger_ativar_gatilho` AFTER UPDATE ON `ocupacaolabirinto` FOR EACH ROW BEGIN
    DECLARE num_tentativas INT;
    DECLARE ultima_hora DATETIME;

    -- Verifica número de tentativas atuais na sala
    SELECT tentativas INTO num_tentativas
    FROM ocupacaolabirinto
    WHERE Sala = NEW.Sala AND IDJogo = NEW.IDJogo;

    -- Obtém a hora do último alerta de gatilho (se existir)
    SELECT MAX(Hora) INTO ultima_hora
    FROM mensagens
    WHERE Msg = 'ativar gatilho'
      AND Sala = NEW.Sala
      AND IDJogo = NEW.IDJogo;

    -- Verifica se passou pelo menos 5 segundos desde o último alerta
    IF NEW.numeromarsamisodd = NEW.numeromarsamiseven
       AND NEW.numeromarsamisodd > 0
       AND num_tentativas < 3
       AND (ultima_hora IS NULL OR TIMESTAMPDIFF(SECOND, ultima_hora, NOW()) >= 5) THEN

        INSERT INTO mensagens (
            Hora, Sala, Sensor, Leitura, TipoAlerta, Msg, HoraEscrita, atuadorAcionado, IDJogo
        )
        VALUES (
            CURRENT_TIMESTAMP, NEW.Sala, 1,
            CONCAT('Odd: ', NEW.numeromarsamisodd, ', Even: ', NEW.numeromarsamiseven),
            'movimento', 'ativar gatilho', CURRENT_TIMESTAMP, FALSE, NEW.IDJogo
        );
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `sound`
--

CREATE TABLE `sound` (
  `IDSound` int(11) NOT NULL,
  `Hora` timestamp NULL DEFAULT current_timestamp(),
  `Sound` double DEFAULT NULL,
  `IDJogo` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `sound`
--

INSERT INTO `sound` (`IDSound`, `Hora`, `Sound`, `IDJogo`) VALUES
(10126, '2025-05-20 12:46:56', 19.542821395042193, 136),
(10127, '2025-05-20 12:46:57', 19.53333333333333, 136),
(10128, '2025-05-20 12:46:58', 19.53333333333333, 136),
(10129, '2025-05-20 12:46:59', 19.7, 136),
(10130, '2025-05-20 12:47:00', 19.615205249382658, 136),
(10131, '2025-05-20 12:47:02', 19.7, 136),
(10132, '2025-05-20 12:47:03', 19.866666666666667, 136),
(10133, '2025-05-20 12:47:04', 19.866666666666667, 136),
(10134, '2025-05-20 12:47:05', 19.866666666666667, 136),
(10135, '2025-05-20 12:47:06', 20.03333333333333, 136),
(10136, '2025-05-20 12:47:07', 20.20651809059176, 136),
(10137, '2025-05-20 12:47:08', 20.03333333333333, 136),
(10138, '2025-05-20 12:47:12', 20.2855959775273, 136),
(10139, '2025-05-20 12:47:13', 20.22027871541741, 136),
(10140, '2025-05-20 12:47:14', 20.366666666666667, 136),
(10141, '2025-05-20 12:47:15', 20.53333333333333, 136),
(10142, '2025-05-20 12:47:16', 20.53333333333333, 136),
(10143, '2025-05-20 12:47:17', 20.53333333333333, 136),
(10144, '2025-05-20 12:47:18', 20.577471513409684, 136),
(10145, '2025-05-20 12:47:19', 20.702294991240688, 136),
(10146, '2025-05-20 12:47:21', 20.7, 136),
(10147, '2025-05-20 12:47:22', 20.7, 136),
(10148, '2025-05-20 12:47:23', 20.866666666666667, 136),
(10149, '2025-05-20 12:47:24', 20.673913527297582, 136),
(10150, '2025-05-20 12:47:25', 20.866666666666667, 136),
(10151, '2025-05-20 12:47:26', 20.903153143966584, 136),
(10152, '0000-00-00 00:00:00', 21.03333333333333, 136),
(10153, '2025-05-20 12:47:28', 21.06433402630851, 136),
(10154, '2025-05-20 12:47:29', 21.2, 136),
(10155, '2025-05-20 12:47:31', 21.2, 136),
(10156, '2025-05-20 12:47:32', 21.271996823055197, 136),
(10157, '2025-05-20 12:47:33', 21.2, 136),
(10158, '2025-05-20 12:47:34', 21.2741674746914, 136),
(10159, '2025-05-20 12:47:35', 21.2, 136),
(10160, '2025-05-20 12:47:36', 21.2, 136),
(10161, '2025-05-20 12:47:37', 21.013413289860214, 136),
(10162, '2025-05-20 12:47:38', 21.093596648434808, 136),
(10163, '2025-05-20 12:47:39', 21.298160853130472, 136),
(10164, '2025-05-20 12:47:41', 21.2, 136),
(10165, '2025-05-20 12:47:42', 21.2, 136),
(10166, '2025-05-20 12:47:43', 21.31678319817984, 136),
(10167, '2025-05-20 12:47:44', 21.2, 136),
(10168, '2025-05-20 12:47:45', 21.026675933636803, 136),
(10169, '2025-05-20 12:47:46', 21.03333333333333, 136),
(10170, '2025-05-20 12:47:47', 21.03333333333333, 136),
(10171, '2025-05-20 12:47:48', 21.07724906775848, 136),
(10172, '2025-05-20 12:47:49', 21.019651490991702, 136),
(10173, '2025-05-20 12:47:51', 20.866666666666667, 136),
(10174, '2025-05-20 12:47:52', 20.72224290944358, 136),
(10175, '2025-05-20 12:47:53', 20.7, 136),
(10176, '2025-05-20 12:47:54', 20.7, 136),
(10177, '2025-05-20 12:47:55', 20.53333333333333, 136),
(10178, '2025-05-20 12:47:56', 20.53333333333333, 136),
(10179, '2025-05-20 12:47:57', 20.396570612485224, 136),
(10180, '2025-05-20 12:47:58', 20.511008603868426, 136),
(10181, '2025-05-20 12:47:59', 20.366666666666667, 136),
(10182, '2025-05-20 12:48:00', 20.366666666666667, 136),
(10183, '2025-05-20 12:48:02', 20.2, 136),
(10184, '2025-05-20 12:48:03', 20.2, 136),
(10185, '2025-05-20 12:48:04', 20.01769984196673, 136),
(10186, '2025-05-20 12:48:05', 20.141108436318774, 136),
(10187, '2025-05-20 12:48:06', 19.915810536924145, 136),
(10188, '2025-05-20 12:48:07', 20.03333333333333, 136),
(10189, '2025-05-20 12:48:08', 20.259971818456453, 136),
(10190, '2025-05-20 12:48:09', 20.03333333333333, 136),
(10191, '2025-05-20 12:48:10', 20.03333333333333, 136),
(10192, '2025-05-20 12:48:12', 20.2, 136),
(10193, '2025-05-20 12:48:13', 20.060093052837377, 136),
(10194, '2025-05-20 12:48:14', 20.03333333333333, 136),
(10195, '2025-05-20 12:48:15', 20.03333333333333, 136),
(10196, '2025-05-20 12:48:16', 19.883547686489376, 136),
(10197, '2025-05-20 12:48:17', 20.03333333333333, 136),
(10198, '2025-05-20 12:48:18', 20.03333333333333, 136),
(10199, '2025-05-20 12:48:19', 20.03333333333333, 136),
(10200, '2025-05-20 12:48:20', 20.03333333333333, 136),
(10201, '2025-05-20 12:48:22', 20.03473884536439, 136),
(10202, '2025-05-20 12:48:23', 20.2, 136),
(10203, '2025-05-20 12:48:24', 20.2, 136),
(10204, '2025-05-20 12:48:25', 20.366666666666667, 136),
(10205, '2025-05-20 12:48:26', 20.366666666666667, 136),
(10206, '2025-05-20 12:48:27', 20.366666666666667, 136),
(10207, '2025-05-20 12:48:28', 20.366666666666667, 136),
(10208, '2025-05-20 12:48:29', 20.53333333333333, 136),
(10209, '2025-05-20 12:48:30', 20.53333333333333, 136),
(10210, '2025-05-20 12:48:32', 20.7, 136),
(10211, '2025-05-20 12:48:33', 20.7, 136),
(10212, '2025-05-20 12:48:34', 20.7, 136),
(10213, '2025-05-20 12:48:35', 20.866666666666667, 136),
(10214, '2025-05-20 12:48:36', 20.866666666666667, 136),
(10215, '2025-05-20 12:48:37', 20.962015216219132, 136),
(10216, '2025-05-20 12:48:38', 20.888132510898515, 136),
(10217, '2025-05-20 12:48:39', 21.205250169542097, 136),
(10218, '2025-05-20 12:48:40', 21.03333333333333, 136),
(10219, '2025-05-20 12:48:41', 21.2, 136),
(10220, '2025-05-20 12:48:42', 21.2, 136),
(10221, '2025-05-20 12:48:44', 21.2, 136),
(10222, '2025-05-20 12:48:45', 21.2, 136),
(10223, '2025-05-20 12:48:46', 21.2, 136),
(10224, '2025-05-20 12:48:47', 21.257952704060322, 136),
(10225, '2025-05-20 12:48:48', 21.2, 136),
(10226, '2025-05-20 12:48:49', 21.2, 136),
(10227, '2025-05-20 12:48:50', 21.2, 136),
(10228, '2025-05-20 12:48:51', 21.2, 136),
(10229, '2025-05-20 12:48:52', 21.2, 136),
(10230, '2025-05-20 12:48:53', 21.2, 136),
(10231, '2025-05-20 12:48:55', 21.2, 136),
(10232, '2025-05-20 12:48:56', 21.2, 136),
(10233, '2025-05-20 12:48:57', 21.11531345553466, 136),
(10234, '2025-05-20 12:48:58', 21.03333333333333, 136),
(10235, '2025-05-20 12:48:59', 21.03333333333333, 136),
(10236, '2025-05-20 12:49:00', 20.866666666666667, 136),
(10237, '2025-05-20 12:49:01', 20.866666666666667, 136),
(10238, '2025-05-20 12:49:02', 20.866666666666667, 136),
(10239, '2025-05-20 12:49:03', 20.866666666666667, 136),
(10240, '2025-05-20 12:49:04', 20.866666666666667, 136),
(10241, '2025-05-20 12:49:06', 20.867582508919185, 136),
(10242, '2025-05-20 12:49:07', 20.7, 136),
(10243, '2025-05-20 12:49:08', 20.53386695490192, 136),
(10244, '2025-05-20 12:49:09', 20.53333333333333, 136),
(10245, '2025-05-20 12:49:10', 20.673201763117717, 136),
(10246, '2025-05-20 12:49:11', 20.366666666666667, 136),
(10247, '2025-05-20 12:49:12', 20.366666666666667, 136),
(10248, '2025-05-20 12:49:13', 20.366666666666667, 136),
(10249, '2025-05-20 12:49:14', 20.046262840315105, 136),
(10250, '2025-05-20 12:49:16', 20.2, 136),
(10251, '2025-05-20 12:49:17', 20.2, 136),
(10252, '2025-05-20 12:49:18', 20.03333333333333, 136),
(10253, '2025-05-20 12:49:19', 20.143017652867634, 136),
(10254, '2025-05-20 12:49:20', 20.03333333333333, 136),
(10255, '2025-05-20 12:49:21', 19.866666666666667, 136),
(10256, '2025-05-20 12:49:22', 19.866666666666667, 136),
(10257, '2025-05-20 12:49:23', 19.866666666666667, 136),
(10258, '2025-05-20 12:49:24', 19.860978679394957, 136),
(10259, '2025-05-20 12:49:26', 19.525476031821743, 136),
(10260, '2025-05-20 12:49:27', 19.7, 136),
(10261, '2025-05-20 12:49:28', 19.7, 136),
(10262, '2025-05-20 12:49:29', 19.77738874030125, 136),
(10263, '2025-05-20 12:49:30', 19.866666666666667, 136),
(10264, '2025-05-20 12:49:31', 19.7, 136),
(10265, '2025-05-20 12:49:32', 19.7, 136),
(10266, '2025-05-20 12:49:33', 19.67059035254393, 136),
(10267, '2025-05-20 12:49:34', 19.69307426040631, 136),
(10268, '2025-05-20 12:49:35', 19.866666666666667, 136),
(10269, '2025-05-20 12:49:37', 19.866666666666667, 136),
(10270, '2025-05-20 12:49:38', 20.001613973194647, 136),
(10271, '2025-05-20 12:49:39', 20.09056062400194, 136),
(10272, '2025-05-20 12:49:40', 20.025145853562965, 136),
(10273, '2025-05-20 12:49:41', 20.143855401408505, 136),
(10274, '2025-05-20 12:49:42', 20.2, 136),
(10275, '2025-05-20 12:49:43', 20.366666666666667, 136),
(10276, '2025-05-20 12:49:44', 20.366666666666667, 136),
(10277, '2025-05-20 12:49:45', 20.366666666666667, 136),
(10278, '2025-05-20 12:49:46', 20.53333333333333, 136),
(10279, '2025-05-20 12:49:48', 20.53333333333333, 136),
(10280, '2025-05-20 12:49:49', 20.53333333333333, 136),
(10281, '2025-05-20 12:49:50', 20.7, 136),
(10282, '2025-05-20 12:49:51', 20.7, 136),
(10283, '2025-05-20 12:49:52', 20.7, 136),
(10284, '2025-05-20 12:49:53', 20.866666666666667, 136),
(10285, '2025-05-20 12:49:54', 20.70445016235788, 136),
(10286, '2025-05-20 12:49:55', 20.866666666666667, 136),
(10287, '2025-05-20 12:49:56', 21.171232860336055, 136),
(10288, '2025-05-20 12:49:57', 21.03333333333333, 136),
(10289, '2025-05-20 12:49:59', 21.03333333333333, 136),
(10290, '2025-05-20 12:50:00', 21.03333333333333, 136),
(10291, '2025-05-20 12:50:01', 21.03333333333333, 136),
(10292, '2025-05-20 12:50:02', 20.989133186756636, 136),
(10293, '2025-05-20 12:50:03', 21.03333333333333, 136),
(10294, '2025-05-20 12:50:04', 21.03333333333333, 136),
(10295, '2025-05-20 12:50:05', 21.03333333333333, 136),
(10296, '2025-05-20 12:50:06', 21.03333333333333, 136),
(10297, '2025-05-20 12:50:07', 21.03333333333333, 136),
(10298, '2025-05-20 12:50:08', 21.03333333333333, 136),
(10299, '2025-05-20 12:50:09', 21.03333333333333, 136),
(10300, '2025-05-20 12:50:11', 21.034265480096547, 136),
(10301, '2025-05-20 12:50:12', 21.03333333333333, 136),
(10302, '2025-05-20 12:50:13', 21.05422756241993, 136),
(10303, '2025-05-20 12:50:14', 21.03333333333333, 136),
(10304, '2025-05-20 12:50:15', 21.03333333333333, 136),
(10305, '2025-05-20 12:50:16', 21.03333333333333, 136),
(10306, '2025-05-20 12:50:17', 20.66946002827724, 136),
(10307, '2025-05-20 12:50:18', 20.866666666666667, 136),
(10308, '2025-05-20 12:50:19', 20.866666666666667, 136),
(10309, '2025-05-20 12:50:20', 20.7, 136),
(10310, '2025-05-20 12:50:22', 20.7, 136),
(10311, '2025-05-20 12:50:23', 20.53333333333333, 136),
(10312, '2025-05-20 12:50:24', 20.53333333333333, 136),
(10313, '2025-05-20 12:50:25', 20.366344249800978, 136),
(10314, '2025-05-20 12:50:26', 20.59389581288866, 136),
(10315, '2025-05-20 12:50:27', 20.366666666666667, 136),
(10316, '2025-05-20 12:50:28', 20.366666666666667, 136),
(10317, '2025-05-20 12:50:29', 20.366666666666667, 136),
(10318, '2025-05-20 12:50:30', 20.2, 136),
(10319, '2025-05-20 12:50:31', 20.2, 136),
(10320, '2025-05-20 12:50:33', 20.2, 136),
(10321, '2025-05-20 12:50:34', 20.03100012525902, 136),
(10322, '2025-05-20 12:50:35', 20.03333333333333, 136),
(10323, '2025-05-20 12:50:36', 19.866666666666667, 136),
(10324, '2025-05-20 12:50:37', 20.036892953906804, 136),
(10325, '2025-05-20 12:50:38', 19.866666666666667, 136),
(10326, '2025-05-20 12:50:39', 19.7, 136),
(10327, '2025-05-20 12:50:40', 19.783039820496032, 136),
(10328, '2025-05-20 12:50:41', 19.7, 136),
(10329, '2025-05-20 12:50:42', 19.7, 136),
(10330, '2025-05-20 12:50:44', 19.357041325980674, 136),
(10331, '2025-05-20 12:50:45', 19.53333333333333, 136);

--
-- Triggers `sound`
--
DELIMITER $$
CREATE TRIGGER `alertaRuido` AFTER INSERT ON `sound` FOR EACH ROW BEGIN
  -- Se o valor de Sound for maior que 21, insere na tabela mensangens
  IF NEW.Sound > 500 THEN
    INSERT INTO mensagens (
      Hora,
      Sala,
      Sensor,
      Leitura,
      TipoAlerta,
      Msg,
      HoraEscrita,
      atuadorAcionado,
      IDJogo
    ) VALUES (
      NEW.Hora,
      NULL,                -- ou informe a Sala se souber
      2,                   -- sensor de som
      NEW.Sound,           -- leitura como DOUBLE
      'sound',
      'fechar portas',
      NOW(),
      0,
      NEW.IDJogo
    );
  END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `alertaRuido2` AFTER INSERT ON `sound` FOR EACH ROW BEGIN
  -- FECHAR PORTAS: quando o som é alto (> 21) e ainda não foi enviado nos últimos 5 segundos
  IF NEW.Sound > 21 THEN
    IF NOT EXISTS (
      SELECT 1 FROM mensagens 
      WHERE IDJogo = NEW.IDJogo
        AND TipoAlerta = 'sound'
        AND Msg = 'fechar portas'
        AND HoraEscrita >= NOW() - INTERVAL 5 SECOND
    ) THEN
      INSERT INTO mensagens (
        Hora,
        Sala,
        Sensor,
        Leitura,
        TipoAlerta,
        Msg,
        HoraEscrita,
        atuadorAcionado,
        IDJogo
      ) VALUES (
        NEW.Hora,
        NULL,
        2,
        NEW.Sound,
        'sound',
        'fechar portas',
        NOW(),
        0,
        NEW.IDJogo
      );
    END IF;
  END IF;

  -- ABRIR PORTAS: quando o som é baixo (< 20) e ainda não foi enviada mensagem nos últimos 5 segundos
  IF NEW.Sound < 20 THEN
    IF NOT EXISTS (
      SELECT 1 FROM mensagens 
      WHERE IDJogo = NEW.IDJogo
        AND TipoAlerta = 'sound'
        AND Msg = 'abrir portas'
        AND HoraEscrita >= NOW() - INTERVAL 5 SECOND
    ) THEN
      INSERT INTO mensagens (
        Hora,
        Sala,
        Sensor,
        Leitura,
        TipoAlerta,
        Msg,
        HoraEscrita,
        atuadorAcionado,
        IDJogo
      ) VALUES (
        NEW.Hora,
        NULL,
        2,
        NEW.Sound,
        'sound',
        'abrir portas',
        NOW(),
        0,
        NEW.IDJogo
      );
    END IF;
  END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `utilizador`
--

CREATE TABLE `utilizador` (
  `ID` int(11) NOT NULL,
  `Nome` varchar(100) NOT NULL,
  `Telemovel` varchar(12) DEFAULT NULL,
  `Tipo` varchar(3) DEFAULT NULL,
  `Email` varchar(50) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `utilizador`
--

INSERT INTO `utilizador` (`ID`, `Nome`, `Telemovel`, `Tipo`, `Email`) VALUES
(44, 'grupo20', NULL, 'U', NULL);

-- --------------------------------------------------------

--
-- Stand-in structure for view `vw_jogos_grupo20`
-- (See below for the actual view)
--
CREATE TABLE `vw_jogos_grupo20` (
`IDJogo` int(11)
,`Descricao` text
,`JogadorID` int(11)
,`DataHoraInicio` timestamp
,`Estado` int(11)
,`Pontuacao` float
);

-- --------------------------------------------------------

--
-- Structure for view `vw_jogos_grupo20`
--
DROP TABLE IF EXISTS `vw_jogos_grupo20`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vw_jogos_grupo20`  AS SELECT `jogo`.`IDJogo` AS `IDJogo`, `jogo`.`Descricao` AS `Descricao`, `jogo`.`JogadorID` AS `JogadorID`, `jogo`.`DataHoraInicio` AS `DataHoraInicio`, `jogo`.`Estado` AS `Estado`, `jogo`.`Pontuacao` AS `Pontuacao` FROM `jogo` WHERE `jogo`.`JogadorID` = (select `utilizador`.`ID` from `utilizador` where `utilizador`.`Nome` = 'grupo20') ;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `jogo`
--
ALTER TABLE `jogo`
  ADD PRIMARY KEY (`IDJogo`),
  ADD KEY `JogadorID` (`JogadorID`);

--
-- Indexes for table `medicoespassagens`
--
ALTER TABLE `medicoespassagens`
  ADD PRIMARY KEY (`IDMedicao`),
  ADD KEY `fk_medicoes_jogo` (`IDJogo`);

--
-- Indexes for table `mensagens`
--
ALTER TABLE `mensagens`
  ADD PRIMARY KEY (`ID`),
  ADD KEY `fk_mensagens_idjogo` (`IDJogo`);

--
-- Indexes for table `ocupacaolabirinto`
--
ALTER TABLE `ocupacaolabirinto`
  ADD PRIMARY KEY (`Sala`,`IDJogo`),
  ADD KEY `IDJogo` (`IDJogo`);

--
-- Indexes for table `sound`
--
ALTER TABLE `sound`
  ADD PRIMARY KEY (`IDSound`),
  ADD KEY `fk_sound_jogo` (`IDJogo`);

--
-- Indexes for table `utilizador`
--
ALTER TABLE `utilizador`
  ADD PRIMARY KEY (`ID`),
  ADD UNIQUE KEY `Nome` (`Nome`),
  ADD UNIQUE KEY `Email` (`Email`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `jogo`
--
ALTER TABLE `jogo`
  MODIFY `IDJogo` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=137;

--
-- AUTO_INCREMENT for table `medicoespassagens`
--
ALTER TABLE `medicoespassagens`
  MODIFY `IDMedicao` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7279;

--
-- AUTO_INCREMENT for table `mensagens`
--
ALTER TABLE `mensagens`
  MODIFY `ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=832;

--
-- AUTO_INCREMENT for table `sound`
--
ALTER TABLE `sound`
  MODIFY `IDSound` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=10332;

--
-- AUTO_INCREMENT for table `utilizador`
--
ALTER TABLE `utilizador`
  MODIFY `ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=45;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `jogo`
--
ALTER TABLE `jogo`
  ADD CONSTRAINT `jogo_ibfk_1` FOREIGN KEY (`JogadorID`) REFERENCES `utilizador` (`ID`);

--
-- Constraints for table `medicoespassagens`
--
ALTER TABLE `medicoespassagens`
  ADD CONSTRAINT `fk_medicoes_jogo` FOREIGN KEY (`IDJogo`) REFERENCES `jogo` (`IDJogo`);

--
-- Constraints for table `mensagens`
--
ALTER TABLE `mensagens`
  ADD CONSTRAINT `fk_mensagens_idjogo` FOREIGN KEY (`IDJogo`) REFERENCES `jogo` (`IDJogo`) ON DELETE CASCADE;

--
-- Constraints for table `ocupacaolabirinto`
--
ALTER TABLE `ocupacaolabirinto`
  ADD CONSTRAINT `ocupacaolabirinto_ibfk_1` FOREIGN KEY (`IDJogo`) REFERENCES `jogo` (`IDJogo`);

--
-- Constraints for table `sound`
--
ALTER TABLE `sound`
  ADD CONSTRAINT `fk_sound_jogo` FOREIGN KEY (`IDJogo`) REFERENCES `jogo` (`IDJogo`);
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
