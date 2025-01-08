/*
---------------------------------------------------------------------------------------
   PROJEKT: "Zarządzanie agencją turystyczną" (TravelAgencyDB)
---------------------------------------------------------------------------------------
   SPIS TREŚCI:
   1.  Tworzenie bazy danych z collation Polish_CS_AS
   2.  Tworzenie tabel słownikowych i głównych
       a) Słowniki (Country, City, PaymentMethodDictionary, TransportTypeDictionary, ReservationStatusDictionary)
       b) Główne (Tour, Client, Reservation, Payment, Guide, Amenity)
       c) Pośrednie (TourGuide, TourAmenity, ReservationAmenity)
   3.  Klucze obce, ograniczenia (PK, FK, UNIQUE, CHECK, DEFAULT)
   4.  Walidacje
   5.  Indeksy nieklastrowane na kluczach obcych
   6.  Wyzwalacze
   7.  Funkcje użytkowe
   8.  Widoki
   9.  Procedury składowane z obsługą TRY…CATCH
       (w tym "wysokopoziomowe": ConfirmReservation, ChangeNumberOfPeople, AddAmenityToReservation, itd.)
   10. Przykładowe INSERTY (w tym do tabel pośrednich i ReservationAmenity)
   11. Konfiguracja bezpieczeństwa (loginy, role, uprawnienia)
   12. Model odzyskiwania danych, backup i restore
   13. Testy i sprawdzanie spójności (procedury biznesowe)
---------------------------------------------------------------------------------------
*/

---------------------------------------------------------------------------------------
-- 0. USUWANIE BAZY DANYCH
---------------------------------------------------------------------------------------

USE [master];
GO

IF DB_ID(N'TravelAgencyDB') IS NOT NULL
BEGIN
    ALTER DATABASE [TravelAgencyDB] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [TravelAgencyDB];
END;
GO


---------------------------------------------------------------------------------------
-- 1. TWORZENIE
---------------------------------------------------------------------------------------
USE [master];
GO

CREATE DATABASE [TravelAgencyDB]
COLLATE Polish_CS_AS;
GO


---------------------------------------------------------------------------------------
-- 2. UŻYWANIE BAZY DANYCH
---------------------------------------------------------------------------------------
USE [TravelAgencyDB];
GO


---------------------------------------------------------------------------------------
-- 3. TWORZENIE TABEL SŁOWNIKOWYCH I GŁÓWNYCH
---------------------------------------------------------------------------------------
/*
   Łącznie tworzymy 14 tabel:
   1)  Country (słownik)
   2)  City (słownik)
   3)  PaymentMethodDictionary (słownik)
   4)  TransportTypeDictionary (słownik)
   5)  ReservationStatusDictionary (słownik)
   6)  Tour
   7)  Client
   8)  Reservation
   9)  Payment
   10) Guide
   11) TourGuide (pośrednia M:N)
   12) Amenity
   13) TourAmenity (pośrednia M:N)
   14) ReservationAmenity (pośrednia w kontekście rezerwacji)
*/

-- Tabela słownikowa: Country
CREATE TABLE [dbo].[Country] (
    [CountryID] INT IDENTITY(1,1) NOT NULL,
    [CountryName] NVARCHAR(100) NOT NULL,
    [CreatedDate] DATETIME2 DEFAULT (GETDATE()),
    [ModifiedDate] DATETIME2 NULL,
    CONSTRAINT [PK_Country] PRIMARY KEY CLUSTERED ([CountryID] ASC)
);
GO

-- Tabela słownikowa: City
CREATE TABLE [dbo].[City] (
    [CityID] INT IDENTITY(1,1) NOT NULL,
    [CountryID] INT NOT NULL,
    [CityName] NVARCHAR(100) NOT NULL,
    [CreatedDate] DATETIME2 DEFAULT (GETDATE()),
    [ModifiedDate] DATETIME2 NULL,
    CONSTRAINT [PK_City] PRIMARY KEY CLUSTERED ([CityID] ASC),
    CONSTRAINT [FK_City_Country] FOREIGN KEY ([CountryID]) REFERENCES [dbo].[Country]([CountryID])
        ON DELETE CASCADE
);
GO

-- Tabela słownikowa: PaymentMethodDictionary
CREATE TABLE [dbo].[PaymentMethodDictionary] (
    [PaymentMethodID] INT IDENTITY(1,1) NOT NULL,
    [PaymentMethodName] NVARCHAR(100) NOT NULL,
    [CreatedDate] DATETIME2 DEFAULT (GETDATE()),
    [ModifiedDate] DATETIME2 NULL,
    CONSTRAINT [PK_PaymentMethodDictionary] PRIMARY KEY CLUSTERED ([PaymentMethodID] ASC)
);
GO

-- Tabela słownikowa: TransportTypeDictionary
CREATE TABLE [dbo].[TransportTypeDictionary] (
    [TransportTypeID] INT IDENTITY(1,1) NOT NULL,
    [TransportTypeName] NVARCHAR(100) NOT NULL,  -- np. Samolot, Autokar, Statek
    [CreatedDate] DATETIME2 DEFAULT (GETDATE()),
    [ModifiedDate] DATETIME2 NULL,
    CONSTRAINT [PK_TransportTypeDictionary] PRIMARY KEY CLUSTERED ([TransportTypeID] ASC)
);
GO

-- Tabela słownikowa: ReservationStatusDictionary
CREATE TABLE [dbo].[ReservationStatusDictionary] (
    [ReservationStatusID] INT IDENTITY(1,1) NOT NULL,
    [ReservationStatusName] NVARCHAR(50) NOT NULL, -- np. Złożona, Potwierdzona, Anulowana
    [CreatedDate] DATETIME2 DEFAULT (GETDATE()),
    [ModifiedDate] DATETIME2 NULL,
    CONSTRAINT [PK_ReservationStatusDictionary] PRIMARY KEY CLUSTERED ([ReservationStatusID] ASC)
);
GO

-- Tabela główna: Tour
CREATE TABLE [dbo].[Tour] (
    [TourID] INT IDENTITY(1,1) NOT NULL,
    [Name] NVARCHAR(200) NOT NULL,
    [CityID] INT NOT NULL,
    [TransportTypeID] INT NOT NULL,
    [StartDate] DATE NOT NULL,
    [EndDate] DATE NOT NULL,
    [Price] DECIMAL(10,2) NOT NULL,
    [AvailableSeats] INT NOT NULL CONSTRAINT [CHK_Tour_AvailableSeats] CHECK ([AvailableSeats] >= 0),
    [CreatedDate] DATETIME2 DEFAULT (GETDATE()),
    [ModifiedDate] DATETIME2 NULL,
    CONSTRAINT [PK_Tour] PRIMARY KEY CLUSTERED ([TourID] ASC),
    CONSTRAINT [FK_Tour_City] FOREIGN KEY ([CityID]) REFERENCES [dbo].[City]([CityID]),
    CONSTRAINT [FK_Tour_TransportType] FOREIGN KEY ([TransportTypeID]) REFERENCES [dbo].[TransportTypeDictionary]([TransportTypeID])
);
GO

-- Tabela główna: Client
CREATE TABLE [dbo].[Client] (
    [ClientID] INT IDENTITY(1,1) NOT NULL,
    [FirstName] NVARCHAR(100) NOT NULL,
    [LastName] NVARCHAR(100) NOT NULL,
    [Email] NVARCHAR(200) NOT NULL,
    [PhoneNumber] NVARCHAR(50) NULL,
    [CreatedDate] DATETIME2 DEFAULT (GETDATE()),
    [ModifiedDate] DATETIME2 NULL,
    CONSTRAINT [PK_Client] PRIMARY KEY CLUSTERED ([ClientID] ASC),
    CONSTRAINT [UQ_Client_Email] UNIQUE ([Email])
);
GO

-- Tabela główna: Reservation
CREATE TABLE [dbo].[Reservation] (
    [ReservationID] INT IDENTITY(1,1) NOT NULL,
    [ClientID] INT NOT NULL,
    [TourID] INT NOT NULL,
    [ReservationDate] DATETIME2 NOT NULL DEFAULT (GETDATE()),
    [NumberOfPeople] INT NOT NULL CONSTRAINT [CHK_Reservation_NumberOfPeople] CHECK ([NumberOfPeople] > 0),
    [ReservationStatusID] INT NOT NULL, 
    [CreatedDate] DATETIME2 DEFAULT (GETDATE()),
    [ModifiedDate] DATETIME2 NULL,
    CONSTRAINT [PK_Reservation] PRIMARY KEY CLUSTERED ([ReservationID] ASC),
    CONSTRAINT [FK_Reservation_Client] FOREIGN KEY ([ClientID]) REFERENCES [dbo].[Client]([ClientID]),
    CONSTRAINT [FK_Reservation_Tour] FOREIGN KEY ([TourID]) REFERENCES [dbo].[Tour]([TourID]),
    CONSTRAINT [FK_Reservation_ReservationStatus] FOREIGN KEY ([ReservationStatusID]) REFERENCES [dbo].[ReservationStatusDictionary]([ReservationStatusID])
);
GO

-- Tabela główna: Payment
CREATE TABLE [dbo].[Payment] (
    [PaymentID] INT IDENTITY(1,1) NOT NULL,
    [ReservationID] INT NOT NULL,
    [PaymentMethodID] INT NOT NULL,  
    [PaymentDate] DATETIME2 NOT NULL DEFAULT (GETDATE()),
    [Amount] DECIMAL(10,2) NOT NULL,
    [CreatedDate] DATETIME2 DEFAULT (GETDATE()),
    [ModifiedDate] DATETIME2 NULL,
    CONSTRAINT [PK_Payment] PRIMARY KEY CLUSTERED ([PaymentID] ASC),
    CONSTRAINT [FK_Payment_Reservation] FOREIGN KEY ([ReservationID]) REFERENCES [dbo].[Reservation]([ReservationID]),
    CONSTRAINT [FK_Payment_PaymentMethodDictionary] FOREIGN KEY ([PaymentMethodID]) REFERENCES [dbo].[PaymentMethodDictionary]([PaymentMethodID])
);
GO

-- Tabela główna: Guide
CREATE TABLE [dbo].[Guide] (
    [GuideID] INT IDENTITY(1,1) NOT NULL,
    [FirstName] NVARCHAR(100) NOT NULL,
    [LastName] NVARCHAR(100) NOT NULL,
    [Specialization] NVARCHAR(200) NULL,
    [CreatedDate] DATETIME2 DEFAULT (GETDATE()),
    [ModifiedDate] DATETIME2 NULL,
    CONSTRAINT [PK_Guide] PRIMARY KEY CLUSTERED ([GuideID] ASC)
);
GO

-- Tabela pośrednia: TourGuide (relacja M:N)
CREATE TABLE [dbo].[TourGuide] (
    [TourID] INT NOT NULL,
    [GuideID] INT NOT NULL,
    [CreatedDate] DATETIME2 DEFAULT (GETDATE()),
    CONSTRAINT [PK_TourGuide] PRIMARY KEY CLUSTERED ([TourID], [GuideID]),
    CONSTRAINT [FK_TourGuide_Tour] FOREIGN KEY ([TourID]) REFERENCES [dbo].[Tour]([TourID]),
    CONSTRAINT [FK_TourGuide_Guide] FOREIGN KEY ([GuideID]) REFERENCES [dbo].[Guide]([GuideID])
);
GO

-- Tabela główna: Amenity
CREATE TABLE [dbo].[Amenity] (
    [AmenityID] INT IDENTITY(1,1) NOT NULL,
    [Name] NVARCHAR(200) NOT NULL,
    [CreatedDate] DATETIME2 DEFAULT (GETDATE()),
    [ModifiedDate] DATETIME2 NULL,
    CONSTRAINT [PK_Amenity] PRIMARY KEY CLUSTERED ([AmenityID] ASC)
);
GO

-- Tabela pośrednia: TourAmenity (M:N między Tour i Amenity)
CREATE TABLE [dbo].[TourAmenity] (
    [TourID] INT NOT NULL,
    [AmenityID] INT NOT NULL,
    [Price] DECIMAL(10,2) NOT NULL,
    [CreatedDate] DATETIME2 DEFAULT (GETDATE()),
    CONSTRAINT [PK_TourAmenity] PRIMARY KEY CLUSTERED ([TourID], [AmenityID]),
    CONSTRAINT [FK_TourAmenity_Tour] FOREIGN KEY ([TourID]) REFERENCES [dbo].[Tour]([TourID]),
    CONSTRAINT [FK_TourAmenity_Amenity] FOREIGN KEY ([AmenityID]) REFERENCES [dbo].[Amenity]([AmenityID])
);
GO

-- Tabela pośrednia: ReservationAmenity (M:N w kontekście rezerwacji)
CREATE TABLE [dbo].[ReservationAmenity] (
    [ReservationAmenityID] INT IDENTITY(1,1) NOT NULL,
    [ReservationID] INT NOT NULL,
    [AmenityID] INT NOT NULL,
    [Price] DECIMAL(10,2) NOT NULL,
    [CreatedDate] DATETIME2 DEFAULT (GETDATE()),
    CONSTRAINT [PK_ReservationAmenity] PRIMARY KEY CLUSTERED ([ReservationAmenityID] ASC),
    CONSTRAINT [FK_ReservationAmenity_Reservation] FOREIGN KEY ([ReservationID]) REFERENCES [dbo].[Reservation]([ReservationID]),
    CONSTRAINT [FK_ReservationAmenity_Amenity] FOREIGN KEY ([AmenityID]) REFERENCES [dbo].[Amenity]([AmenityID])
);
GO


---------------------------------------------------------------------------------------
-- 4. WALIDACJE
---------------------------------------------------------------------------------------

-- Walidacja adresu email na tabeli Client
ALTER TABLE [dbo].[Client]
ADD CONSTRAINT [CHK_Client_Email] 
CHECK (Email LIKE '%_@__%.__%');

-- Walidacja numeru telefonu na tabeli Client
ALTER TABLE [dbo].[Client]
ADD CONSTRAINT [CHK_Client_PhoneNumber] 
CHECK (PhoneNumber LIKE '+%[0-9]%' OR PhoneNumber IS NULL);

-- Walidacja wielkości kwoty na tabeli Payment
ALTER TABLE [dbo].[Payment]
ADD CONSTRAINT [CHK_Payment_Amount] 
CHECK (Amount > 0);

-- Walidacja dat wycieczki na tabeli Tour
ALTER TABLE [dbo].[Tour]
ADD CONSTRAINT [CHK_Tour_Dates] 
CHECK (EndDate > StartDate);

-- Walidacja ceny wycieczki na tabeli Tour
ALTER TABLE [dbo].[Tour]
ADD CONSTRAINT [CHK_Tour_Price] 
CHECK (Price > 0);

-- Walidacja ceny na tabeli TourAmenity
ALTER TABLE [dbo].[TourAmenity]
ADD CONSTRAINT [CHK_TourAmenity_Price] 
CHECK (Price >= 0);

-- Walidacja ceny na tabeli ReservationAmenity
ALTER TABLE [dbo].[ReservationAmenity]
ADD CONSTRAINT [CHK_ReservationAmenity_Price]
CHECK (Price >= 0);


---------------------------------------------------------------------------------------
-- 5. INDEKSY NIEKLASTROWANE NA KLUCZACH OBCYCH
---------------------------------------------------------------------------------------
-- Tabela Reservation
CREATE NONCLUSTERED INDEX [IX_Reservation_ClientID] 
    ON [dbo].[Reservation]([ClientID]);
CREATE NONCLUSTERED INDEX [IX_Reservation_TourID] 
    ON [dbo].[Reservation]([TourID]);
CREATE NONCLUSTERED INDEX [IX_Reservation_ReservationStatusID]
    ON [dbo].[Reservation]([ReservationStatusID]);

-- Tabela Payment
CREATE NONCLUSTERED INDEX [IX_Payment_ReservationID]
    ON [dbo].[Payment]([ReservationID]);
CREATE NONCLUSTERED INDEX [IX_Payment_PaymentMethodID]
    ON [dbo].[Payment]([PaymentMethodID]);

-- Tabela TourGuide
CREATE NONCLUSTERED INDEX [IX_TourGuide_GuideID]
    ON [dbo].[TourGuide]([GuideID]);

-- Tabela TourAmenity
CREATE NONCLUSTERED INDEX [IX_TourAmenity_AmenityID]
    ON [dbo].[TourAmenity]([AmenityID]);

-- Tabela City
CREATE NONCLUSTERED INDEX [IX_City_CountryID]
    ON [dbo].[City]([CountryID]);

-- Tabela Tour
CREATE NONCLUSTERED INDEX [IX_Tour_CityID]
    ON [dbo].[Tour]([CityID]);
CREATE NONCLUSTERED INDEX [IX_Tour_TransportTypeID]
    ON [dbo].[Tour]([TransportTypeID]);

-- Tabela ReservationAmenity
CREATE NONCLUSTERED INDEX [IX_ReservationAmenity_ReservationID]
    ON [dbo].[ReservationAmenity]([ReservationID]);
CREATE NONCLUSTERED INDEX [IX_ReservationAmenity_AmenityID]
    ON [dbo].[ReservationAmenity]([AmenityID]);
GO


---------------------------------------------------------------------------------------
-- 6. WYZWALACZE
---------------------------------------------------------------------------------------

-- Wyzwalacz na Amenity, aktualizujący ModifiedDate
CREATE TRIGGER [dbo].[TRG_Amenity_ModifiedDate]
ON [dbo].[Amenity]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.Amenity
    SET ModifiedDate = GETDATE()
    FROM Inserted i
    WHERE dbo.Amenity.AmenityID = i.AmenityID;
END;
GO

-- Wyzwalacz na PaymentMethodDictionary, aktualizujący ModifiedDate
CREATE TRIGGER [dbo].[TRG_PaymentMethodDictionary_ModifiedDate]
ON [dbo].[PaymentMethodDictionary]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.PaymentMethodDictionary
    SET ModifiedDate = GETDATE()
    FROM Inserted i
    WHERE dbo.PaymentMethodDictionary.PaymentMethodID = i.PaymentMethodID;
END;
GO


---------------------------------------------------------------------------------------
-- 7. FUNKCJE UŻYTKOWE
---------------------------------------------------------------------------------------

-- Funkcja obliczająca całkowity koszt wycieczki, wliczając w to udogodnienia
CREATE OR ALTER FUNCTION [dbo].[fn_CalculateTotalTourCost]
(
    @TourID INT,
    @NumberOfPeople INT
)
RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @TotalCost DECIMAL(10,2);
    
    SELECT @TotalCost = (t.Price * @NumberOfPeople) + 
           (SELECT ISNULL(SUM(ta.Price * @NumberOfPeople), 0)
            FROM [dbo].[TourAmenity] ta
            WHERE ta.TourID = t.TourID)
    FROM [dbo].[Tour] t
    WHERE t.TourID = @TourID;
    
    RETURN ISNULL(@TotalCost, 0);
END;
GO

-- Funkcja sprawdzająca, czy na wycieczkę są dostępne miejsca
CREATE OR ALTER FUNCTION [dbo].[fn_IsTourAvailable]
(
    @TourID INT,
    @RequestedSeats INT
)
RETURNS BIT
AS
BEGIN
    DECLARE @AvailableSeats INT;
    
    SELECT @AvailableSeats = t.AvailableSeats - ISNULL(SUM(r.NumberOfPeople), 0)
    FROM [dbo].[Tour] t
    LEFT JOIN [dbo].[Reservation] r ON t.TourID = r.TourID
    WHERE t.TourID = @TourID AND r.ReservationStatusID <> 3  -- 3 = 'Anulowana'
    GROUP BY t.AvailableSeats;
    
    RETURN CASE WHEN @AvailableSeats >= @RequestedSeats THEN 1 ELSE 0 END;
END;
GO


---------------------------------------------------------------------------------------
-- 8. WIDOKI
---------------------------------------------------------------------------------------

-- Widok nadchodzących wycieczek razem z ilością dostępnych miejsc
CREATE OR ALTER VIEW [dbo].[vw_UpcomingToursAvailability]
AS
SELECT 
    t.TourID,
    t.Name AS TourName,
    c.CityName,
    co.CountryName,
    t.StartDate,
    t.EndDate,
    t.Price,
    t.AvailableSeats - ISNULL(SUM(
        CASE WHEN r.ReservationStatusID <> 3 THEN r.NumberOfPeople ELSE 0 END
    ), 0) AS RemainingSeats,
    tt.TransportTypeName
FROM [dbo].[Tour] t
JOIN [dbo].[City] c ON t.CityID = c.CityID
JOIN [dbo].[Country] co ON c.CountryID = co.CountryID
JOIN [dbo].[TransportTypeDictionary] tt ON t.TransportTypeID = tt.TransportTypeID
LEFT JOIN [dbo].[Reservation] r ON t.TourID = r.TourID 
WHERE t.StartDate > GETDATE()
GROUP BY 
    t.TourID, t.Name, c.CityName, co.CountryName, t.StartDate, t.EndDate,
    t.Price, t.AvailableSeats, tt.TransportTypeName;
GO

-- Widok podsumowania rezerwacji
CREATE OR ALTER VIEW [dbo].[vw_ReservationSummary]
AS
SELECT 
    r.ReservationID,
    c.FirstName + ' ' + c.LastName AS ClientName,
    t.Name AS TourName,
    r.NumberOfPeople,
    rsd.ReservationStatusName,
    r.ReservationDate,
    p.Amount AS PaidAmount,
    pm.PaymentMethodName,
    dbo.fn_CalculateTotalTourCost(t.TourID, r.NumberOfPeople) AS TotalCost
FROM [dbo].[Reservation] r
JOIN [dbo].[Client] c ON r.ClientID = c.ClientID
JOIN [dbo].[Tour] t   ON r.TourID  = t.TourID
LEFT JOIN [dbo].[Payment] p ON r.ReservationID = p.ReservationID
LEFT JOIN [dbo].[PaymentMethodDictionary] pm ON p.PaymentMethodID = pm.PaymentMethodID
JOIN [dbo].[ReservationStatusDictionary] rsd ON r.ReservationStatusID = rsd.ReservationStatusID;
GO


---------------------------------------------------------------------------------------
-- 9. PROCEDURY SKŁADOWANE (INSERT) Z OBSŁUGĄ TRY…CATCH
---------------------------------------------------------------------------------------

--------------------------
-- COUNTRY
--------------------------
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'usp_InsertCountry')
    DROP PROCEDURE [dbo].[usp_InsertCountry];
GO

CREATE PROCEDURE [dbo].[usp_InsertCountry]
    @CountryName NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO [dbo].[Country] ([CountryName])
        VALUES (@CountryName);
    END TRY
    BEGIN CATCH
        SELECT ERROR_NUMBER() AS ErrorNumber, ERROR_MESSAGE() AS ErrorMessage;
    END CATCH
END;
GO

--------------------------
-- CITY
--------------------------
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'usp_InsertCity')
    DROP PROCEDURE [dbo].[usp_InsertCity];
GO

CREATE PROCEDURE [dbo].[usp_InsertCity]
    @CountryID INT,
    @CityName NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO [dbo].[City] ([CountryID], [CityName])
        VALUES (@CountryID, @CityName);
    END TRY
    BEGIN CATCH
        SELECT ERROR_NUMBER() AS ErrorNumber, ERROR_MESSAGE() AS ErrorMessage;
    END CATCH
END;
GO

--------------------------
-- PAYMENT METHOD DICTIONARY
--------------------------
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'usp_InsertPaymentMethodDictionary')
    DROP PROCEDURE [dbo].[usp_InsertPaymentMethodDictionary];
GO

CREATE PROCEDURE [dbo].[usp_InsertPaymentMethodDictionary]
    @PaymentMethodName NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO [dbo].[PaymentMethodDictionary] ([PaymentMethodName])
        VALUES (@PaymentMethodName);
    END TRY
    BEGIN CATCH
        SELECT ERROR_NUMBER() AS ErrorNumber, ERROR_MESSAGE() AS ErrorMessage;
    END CATCH
END;
GO

--------------------------
-- TRANSPORT TYPE DICTIONARY
--------------------------
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'usp_InsertTransportTypeDictionary')
    DROP PROCEDURE [dbo].[usp_InsertTransportTypeDictionary];
GO

CREATE PROCEDURE [dbo].[usp_InsertTransportTypeDictionary]
    @TransportTypeName NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO [dbo].[TransportTypeDictionary] ([TransportTypeName])
        VALUES (@TransportTypeName);
    END TRY
    BEGIN CATCH
        SELECT ERROR_NUMBER() AS ErrorNumber, ERROR_MESSAGE() AS ErrorMessage;
    END CATCH
END;
GO

--------------------------
-- RESERVATION STATUS DICTIONARY
--------------------------
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'usp_InsertReservationStatusDictionary')
    DROP PROCEDURE [dbo].[usp_InsertReservationStatusDictionary];
GO

CREATE PROCEDURE [dbo].[usp_InsertReservationStatusDictionary]
    @ReservationStatusName NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO [dbo].[ReservationStatusDictionary] ([ReservationStatusName])
        VALUES (@ReservationStatusName);
    END TRY
    BEGIN CATCH
        SELECT ERROR_NUMBER() AS ErrorNumber, ERROR_MESSAGE() AS ErrorMessage;
    END CATCH
END;
GO

--------------------------
-- TOUR
--------------------------
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'usp_InsertTour')
    DROP PROCEDURE [dbo].[usp_InsertTour];
GO

CREATE PROCEDURE [dbo].[usp_InsertTour]
    @Name NVARCHAR(200),
    @CityID INT,
    @TransportTypeID INT,
    @StartDate DATE,
    @EndDate DATE,
    @Price DECIMAL(10,2),
    @AvailableSeats INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO [dbo].[Tour] (
            [Name], [CityID], [TransportTypeID], [StartDate], [EndDate], [Price], [AvailableSeats]
        )
        VALUES (
            @Name, @CityID, @TransportTypeID, @StartDate, @EndDate, @Price, @AvailableSeats
        );
    END TRY
    BEGIN CATCH
        SELECT ERROR_NUMBER() AS ErrorNumber, ERROR_MESSAGE() AS ErrorMessage;
    END CATCH
END;
GO

--------------------------
-- CLIENT
--------------------------
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'usp_InsertClient')
    DROP PROCEDURE [dbo].[usp_InsertClient];
GO

CREATE PROCEDURE [dbo].[usp_InsertClient]
    @FirstName NVARCHAR(100),
    @LastName NVARCHAR(100),
    @Email NVARCHAR(200),
    @PhoneNumber NVARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO [dbo].[Client] ([FirstName], [LastName], [Email], [PhoneNumber])
        VALUES (@FirstName, @LastName, @Email, @PhoneNumber);
    END TRY
    BEGIN CATCH
        SELECT ERROR_NUMBER() AS ErrorNumber, ERROR_MESSAGE() AS ErrorMessage;
    END CATCH
END;
GO

--------------------------
-- RESERVATION (INSERT)
--------------------------
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'usp_InsertReservation')
    DROP PROCEDURE [dbo].[usp_InsertReservation];
GO

CREATE PROCEDURE [dbo].[usp_InsertReservation]
    @ClientID INT,
    @TourID INT,
    @NumberOfPeople INT,
    @ReservationStatusID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO [dbo].[Reservation] (
            [ClientID], [TourID], [NumberOfPeople], [ReservationStatusID]
        )
        VALUES (
            @ClientID, @TourID, @NumberOfPeople, @ReservationStatusID
        );
    END TRY
    BEGIN CATCH
        SELECT ERROR_NUMBER() AS ErrorNumber, ERROR_MESSAGE() AS ErrorMessage;
    END CATCH
END;
GO

--------------------------
-- RESERVATION WITH PAYMENT
--------------------------
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'usp_CreateReservationWithPayment')
    DROP PROCEDURE [dbo].[usp_CreateReservationWithPayment];
GO

CREATE OR ALTER PROCEDURE [dbo].[usp_CreateReservationWithPayment]
    @ClientID INT,
    @TourID INT,
    @NumberOfPeople INT,
    @ReservationStatusID INT = 1,   -- Domyślnie 1 = 'Złożona'
    @PaymentMethodID INT = NULL,
    @InitialPayment DECIMAL(10,2) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF dbo.[fn_IsTourAvailable](@TourID, @NumberOfPeople) = 0
            THROW 50001, 'Ta wycieczka nie posiada wystarczająco wolnych miejsc.', 1;
        
        BEGIN TRANSACTION;
            INSERT INTO [dbo].[Reservation] (
                [ClientID], [TourID], [NumberOfPeople], [ReservationStatusID]
            )
            VALUES (
                @ClientID, @TourID, @NumberOfPeople, @ReservationStatusID
            );
            
            DECLARE @ReservationID INT = SCOPE_IDENTITY();
            
            IF @PaymentMethodID IS NOT NULL AND @InitialPayment > 0
            BEGIN
                INSERT INTO [dbo].[Payment] (
                    [ReservationID], [PaymentMethodID], [Amount]
                )
                VALUES (
                    @ReservationID, @PaymentMethodID, @InitialPayment
                );
            END
            
        COMMIT;
        
        SELECT * FROM [dbo].[vw_ReservationSummary] 
        WHERE ReservationID = @ReservationID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 
            ROLLBACK;
        THROW;
    END CATCH;
END;
GO

--------------------------
-- CANCEL RESERVATION
--------------------------
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'usp_CancelReservation')
    DROP PROCEDURE [dbo].[usp_CancelReservation];
GO

CREATE OR ALTER PROCEDURE [dbo].[usp_CancelReservation]
    @ReservationID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
            UPDATE [dbo].[Reservation]
            SET [ReservationStatusID] = 3
            WHERE ReservationID = @ReservationID;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 
            ROLLBACK;
        THROW;
    END CATCH;
END;
GO

--------------------------
-- PAYMENT
--------------------------
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'usp_InsertPayment')
    DROP PROCEDURE [dbo].[usp_InsertPayment];
GO

CREATE PROCEDURE [dbo].[usp_InsertPayment]
    @ReservationID INT,
    @PaymentMethodID INT,
    @Amount DECIMAL(10,2)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO [dbo].[Payment] ([ReservationID], [PaymentMethodID], [Amount])
        VALUES (@ReservationID, @PaymentMethodID, @Amount);
    END TRY
    BEGIN CATCH
        SELECT ERROR_NUMBER() AS ErrorNumber, ERROR_MESSAGE() AS ErrorMessage;
    END CATCH
END;
GO

--------------------------
-- GUIDE
--------------------------
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'usp_InsertGuide')
    DROP PROCEDURE [dbo].[usp_InsertGuide];
GO

CREATE PROCEDURE [dbo].[usp_InsertGuide]
    @FirstName NVARCHAR(100),
    @LastName NVARCHAR(100),
    @Specialization NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO [dbo].[Guide] ([FirstName], [LastName], [Specialization])
        VALUES (@FirstName, @LastName, @Specialization);
    END TRY
    BEGIN CATCH
        SELECT ERROR_NUMBER() AS ErrorNumber, ERROR_MESSAGE() AS ErrorMessage;
    END CATCH
END;
GO

--------------------------
-- AMENITY
--------------------------
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'usp_InsertAmenity')
    DROP PROCEDURE [dbo].[usp_InsertAmenity];
GO

CREATE PROCEDURE [dbo].[usp_InsertAmenity]
    @Name NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO [dbo].[Amenity] ([Name])
        VALUES (@Name);
    END TRY
    BEGIN CATCH
        SELECT ERROR_NUMBER() AS ErrorNumber, ERROR_MESSAGE() AS ErrorMessage;
    END CATCH
END;
GO

--------------------------
-- RESERVATION AMENITY (INSERT)
--------------------------
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'usp_InsertReservationAmenity')
    DROP PROCEDURE [dbo].[usp_InsertReservationAmenity];
GO

CREATE PROCEDURE [dbo].[usp_InsertReservationAmenity]
    @ReservationID INT,
    @AmenityID INT,
    @Price DECIMAL(10,2)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO [dbo].[ReservationAmenity] ([ReservationID], [AmenityID], [Price])
        VALUES (@ReservationID, @AmenityID, @Price);
    END TRY
    BEGIN CATCH
        SELECT ERROR_NUMBER() AS ErrorNumber, ERROR_MESSAGE() AS ErrorMessage;
    END CATCH
END;
GO

--------------------------
-- INNE
--------------------------

-- 1) Potwierdzenie rezerwacji (z opcją dodatkowej płatności)
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'usp_ConfirmReservation')
    DROP PROCEDURE [dbo].[usp_ConfirmReservation];
GO

CREATE PROCEDURE [dbo].[usp_ConfirmReservation]
    @ReservationID INT,
    @PaymentMethodID INT = NULL,   
    @PaymentAmount DECIMAL(10,2) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Sprawdzamy, czy rezerwacja jest Złożona (ID=1)
        DECLARE @CurrentStatusID INT;
        SELECT @CurrentStatusID = ReservationStatusID
        FROM [dbo].[Reservation]
        WHERE ReservationID = @ReservationID;

        IF @CurrentStatusID IS NULL
        BEGIN
            THROW 50001, 'Nie znaleziono wskazanej rezerwacji.', 1;
        END

        IF @CurrentStatusID <> 1
        BEGIN
            THROW 50002, 'Rezerwacja nie jest w statusie Złożona - nie można potwierdzić.', 1;
        END

        -- Ustawiamy na Potwierdzona (ID=2)
        UPDATE [dbo].[Reservation]
        SET ReservationStatusID = 2
        WHERE ReservationID = @ReservationID;

        -- Dodatkowa płatność (opcjonalnie)
        IF @PaymentMethodID IS NOT NULL AND @PaymentAmount > 0
        BEGIN
            INSERT INTO [dbo].[Payment]
            (
                [ReservationID],
                [PaymentMethodID],
                [Amount]
            )
            VALUES
            (
                @ReservationID,
                @PaymentMethodID,
                @PaymentAmount
            );
        END

        COMMIT;

        -- Zwracamy aktualne podsumowanie
        SELECT *
        FROM [dbo].[vw_ReservationSummary]
        WHERE ReservationID = @ReservationID;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        THROW;
    END CATCH;
END;
GO

-- 2) Zmiana liczby osób w rezerwacji
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'usp_ChangeNumberOfPeople')
    DROP PROCEDURE [dbo].[usp_ChangeNumberOfPeople];
GO

CREATE PROCEDURE [dbo].[usp_ChangeNumberOfPeople]
    @ReservationID INT,
    @NewNumberOfPeople INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @OldNumberOfPeople INT, @TourID INT, @StatusID INT;
        SELECT 
            @OldNumberOfPeople = NumberOfPeople,
            @TourID            = TourID,
            @StatusID          = ReservationStatusID
        FROM [dbo].[Reservation]
        WHERE ReservationID = @ReservationID;

        IF @StatusID IS NULL
        BEGIN
            THROW 51001, 'Nie znaleziono wskazanej rezerwacji.', 1;
        END

        IF @StatusID = 3  -- 3 = Anulowana
        BEGIN
            THROW 51002, 'Rezerwacja jest anulowana - nie można zmienić liczby osób.', 1;
        END

        IF @NewNumberOfPeople <= 0
        BEGIN
            THROW 51003, 'Liczba osób musi być większa od zera.', 1;
        END

        -- Jeśli zwiększamy liczbę osób, sprawdzamy dostępność miejsc
        IF @NewNumberOfPeople > @OldNumberOfPeople
        BEGIN
            DECLARE @IsAvailable BIT = dbo.fn_IsTourAvailable(@TourID, @NewNumberOfPeople);
            IF @IsAvailable = 0
            BEGIN
                THROW 51004, 'Nie ma wystarczającej liczby miejsc na tej wycieczce.', 1;
            END
        END

        UPDATE [dbo].[Reservation]
        SET NumberOfPeople = @NewNumberOfPeople
        WHERE ReservationID = @ReservationID;

        COMMIT;

        -- Zwracamy aktualne podsumowanie
        SELECT *
        FROM [dbo].[vw_ReservationSummary]
        WHERE ReservationID = @ReservationID;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        THROW;
    END CATCH;
END;
GO

-- 3) Dodanie udogodnienia do rezerwacji
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'usp_AddAmenityToReservation')
    DROP PROCEDURE [dbo].[usp_AddAmenityToReservation];
GO

CREATE PROCEDURE [dbo].[usp_AddAmenityToReservation]
    @ReservationID INT,
    @AmenityID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @TourID INT, @StatusID INT;
        SELECT @TourID = r.TourID,
               @StatusID = r.ReservationStatusID
        FROM [dbo].[Reservation] r
        WHERE r.ReservationID = @ReservationID;

        IF @TourID IS NULL
        BEGIN
            THROW 52001, 'Nie znaleziono wskazanej rezerwacji.', 1;
        END

        IF @StatusID = 3
        BEGIN
            THROW 52002, 'Rezerwacja jest anulowana - nie można dodać udogodnienia.', 1;
        END

        DECLARE @AmenityPrice DECIMAL(10,2);
        SELECT @AmenityPrice = ta.Price
        FROM [dbo].[TourAmenity] ta
        WHERE ta.TourID = @TourID
          AND ta.AmenityID = @AmenityID;

        IF @AmenityPrice IS NULL
        BEGIN
            THROW 52003, 'Wycieczka nie oferuje podanego udogodnienia (Amenity).', 1;
        END

        INSERT INTO [dbo].[ReservationAmenity] ([ReservationID], [AmenityID], [Price])
        VALUES (@ReservationID, @AmenityID, @AmenityPrice);

        COMMIT;

        -- Lista wszystkich udogodnień w rezerwacji
        SELECT ra.ReservationAmenityID,
               ra.ReservationID,
               a.Name AS AmenityName,
               ra.Price
        FROM [dbo].[ReservationAmenity] ra
        JOIN [dbo].[Amenity] a ON ra.AmenityID = a.AmenityID
        WHERE ra.ReservationID = @ReservationID;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        THROW;
    END CATCH;
END;
GO

-- 4) Zaktualizowanie ceny udogodnienia w rezerwacji
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'usp_UpdateAmenityPriceInReservation')
    DROP PROCEDURE [dbo].[usp_UpdateAmenityPriceInReservation];
GO

CREATE PROCEDURE [dbo].[usp_UpdateAmenityPriceInReservation]
    @ReservationAmenityID INT,
    @NewPrice DECIMAL(10,2)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        IF @NewPrice < 0
        BEGIN
            THROW 53001, 'Cena nie może być ujemna.', 1;
        END

        UPDATE [dbo].[ReservationAmenity]
        SET Price = @NewPrice
        WHERE ReservationAmenityID = @ReservationAmenityID;

        IF @@ROWCOUNT = 0
        BEGIN
            THROW 53002, 'Nie znaleziono wskazanego rekordu ReservationAmenity.', 1;
        END

        COMMIT;

        SELECT *
        FROM [dbo].[ReservationAmenity]
        WHERE ReservationAmenityID = @ReservationAmenityID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        THROW;
    END CATCH;
END;
GO

-- 5) Pobranie pełnych informacji o rezerwacji (2 zestawy danych)
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'usp_GetReservationDetails')
    DROP PROCEDURE [dbo].[usp_GetReservationDetails];
GO

CREATE PROCEDURE [dbo].[usp_GetReservationDetails]
    @ReservationID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Pierwszy SELECT: dane z vw_ReservationSummary
        SELECT *
        FROM [dbo].[vw_ReservationSummary]
        WHERE ReservationID = @ReservationID;

        -- Drugi SELECT: wszystkie amenity w rezerwacji
        SELECT ra.ReservationAmenityID,
               a.AmenityID,
               a.Name AS AmenityName,
               ra.Price
        FROM [dbo].[ReservationAmenity] ra
        JOIN [dbo].[Amenity] a ON ra.AmenityID = a.AmenityID
        WHERE ra.ReservationID = @ReservationID;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH;
END;
GO


---------------------------------------------------------------------------------------
-- 10. PRZYKŁADOWE WYPEŁNIANIE DANYMI
---------------------------------------------------------------------------------------
/*
   Wypełniamy słowniki i tabele główne, pośrednie.
   Dodajemy 1 rezerwację przykładową (ClientID=1, TourID=1, Status=Złożona).
*/

-- 10.1 SŁOWNIKI
EXEC [dbo].[usp_InsertCountry] @CountryName = N'Polska';
EXEC [dbo].[usp_InsertCountry] @CountryName = N'Grecja';
EXEC [dbo].[usp_InsertCountry] @CountryName = N'Włochy';

EXEC [dbo].[usp_InsertCity] @CountryID = 1, @CityName = N'Warszawa';
EXEC [dbo].[usp_InsertCity] @CountryID = 2, @CityName = N'Ateny';
EXEC [dbo].[usp_InsertCity] @CountryID = 3, @CityName = N'Rzym';

EXEC [dbo].[usp_InsertPaymentMethodDictionary] @PaymentMethodName = N'Przelew';
EXEC [dbo].[usp_InsertPaymentMethodDictionary] @PaymentMethodName = N'Karta';
EXEC [dbo].[usp_InsertPaymentMethodDictionary] @PaymentMethodName = N'Gotówka';

EXEC [dbo].[usp_InsertTransportTypeDictionary] @TransportTypeName = N'Samolot';
EXEC [dbo].[usp_InsertTransportTypeDictionary] @TransportTypeName = N'Autokar';
EXEC [dbo].[usp_InsertTransportTypeDictionary] @TransportTypeName = N'Statek';

-- ReservationStatusDictionary
EXEC [dbo].[usp_InsertReservationStatusDictionary] @ReservationStatusName = N'Złożona';       -- ID=1
EXEC [dbo].[usp_InsertReservationStatusDictionary] @ReservationStatusName = N'Potwierdzona'; -- ID=2
EXEC [dbo].[usp_InsertReservationStatusDictionary] @ReservationStatusName = N'Anulowana';    -- ID=3

-- 10.2 TABEL GŁÓWNYCH
EXEC [dbo].[usp_InsertAmenity] @Name = N'Ubezpieczenie';
EXEC [dbo].[usp_InsertAmenity] @Name = N'Transfer z lotniska';
EXEC [dbo].[usp_InsertAmenity] @Name = N'Rejs statkiem';

EXEC [dbo].[usp_InsertClient] 
    @FirstName = N'Jan', 
    @LastName  = N'Kowalski', 
    @Email     = N'jan.kowalski@example.com', 
    @PhoneNumber = N'+48 123-456-789';

EXEC [dbo].[usp_InsertClient] 
    @FirstName = N'Anna', 
    @LastName  = N'Nowak', 
    @Email     = N'anna.nowak@example.com', 
    @PhoneNumber = N'+48 987-654-321';

EXEC [dbo].[usp_InsertGuide] 
    @FirstName = N'Adam', 
    @LastName  = N'Malinowski', 
    @Specialization = N'Sporty wodne';

EXEC [dbo].[usp_InsertGuide] 
    @FirstName = N'Katarzyna', 
    @LastName  = N'Wiśniewska', 
    @Specialization = N'Zabytki i muzea';

EXEC [dbo].[usp_InsertTour]
    @Name            = N'Wakacje w Grecji',
    @CityID          = 2,
    @TransportTypeID = 1,
    @StartDate       = '2025-06-10',
    @EndDate         = '2025-06-20',
    @Price           = 2999.99,
    @AvailableSeats  = 30;

EXEC [dbo].[usp_InsertTour]
    @Name            = N'Zwiedzanie Włoch',
    @CityID          = 3,
    @TransportTypeID = 2,
    @StartDate       = '2025-09-01',
    @EndDate         = '2025-09-10',
    @Price           = 3599.99,
    @AvailableSeats  = 20;

-- 10.3 TABELA POŚREDNIA: TourGuide
INSERT INTO [dbo].[TourGuide] ([TourID], [GuideID])
VALUES 
    (1, 1),  -- TourID=1, GuideID=1
    (1, 2),  -- Wakacje w Grecji + Katarzyna
    (2, 2);  -- Zwiedzanie Włoch + Katarzyna

-- 10.4 TABELA POŚREDNIA: TourAmenity
INSERT INTO [dbo].[TourAmenity] ([TourID], [AmenityID], [Price])
VALUES
    (1, 1, 50.00),    -- Wakacje w Grecji + Ubezpieczenie
    (1, 2, 100.00),   -- Wakacje w Grecji + Transfer
    (1, 3, 150.00),   -- Wakacje w Grecji + Rejs
    (2, 1, 80.00),    -- Zwiedzanie Włoch + Ubezpieczenie
    (2, 2, 120.00);   -- Zwiedzanie Włoch + Transfer

-- 10.5 REZERWACJA (Złożona)
EXEC [dbo].[usp_InsertReservation]
    @ClientID         = 1,
    @TourID           = 1,
    @NumberOfPeople   = 2,
    @ReservationStatusID = 1;   -- Złożona

-- 10.6 PAYMENT
EXEC [dbo].[usp_InsertPayment]
    @ReservationID   = 1,
    @PaymentMethodID = 2,    -- Karta
    @Amount          = 5999.98;

-- 10.7 RESERVATION AMENITY
EXEC [dbo].[usp_InsertReservationAmenity]
    @ReservationID = 1,
    @AmenityID     = 1,   -- Ubezpieczenie
    @Price         = 50.00;


---------------------------------------------------------------------------------------
-- 11. KONFIGURACJA BEZPIECZEŃSTWA (LOGINY, ROLE, UŻYTKOWNICY)
---------------------------------------------------------------------------------------
USE [master];
GO

-- Przykładowe loginy
IF NOT EXISTS (SELECT * FROM sys.server_principals WHERE name = N'TravelManager')
BEGIN
    CREATE LOGIN [TravelManager] WITH PASSWORD = 'StrongPassword123!';
END;
IF NOT EXISTS (SELECT * FROM sys.server_principals WHERE name = N'TravelViewer')
BEGIN
    CREATE LOGIN [TravelViewer] WITH PASSWORD = 'ViewerPassword123!';
END;
IF NOT EXISTS (SELECT * FROM sys.server_principals WHERE name = N'AgentJohn')
BEGIN
    CREATE LOGIN [AgentJohn] WITH PASSWORD = 'Agent123!';
END;
GO

USE [TravelAgencyDB];
GO

IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'TravelManager')
BEGIN
    CREATE USER [TravelManager] FOR LOGIN [TravelManager];
END;
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'TravelViewer')
BEGIN
    CREATE USER [TravelViewer] FOR LOGIN [TravelViewer];
END;
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'AgentJohn')
BEGIN
    CREATE USER [AgentJohn] FOR LOGIN [AgentJohn];
END;
GO

IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'TravelAgent' AND type = 'R')
BEGIN
    CREATE ROLE [TravelAgent];
END;
GO

GRANT SELECT ON [dbo].[vw_UpcomingToursAvailability] TO [TravelAgent];
GRANT SELECT ON [dbo].[vw_ReservationSummary] TO [TravelAgent];
GRANT EXECUTE ON [dbo].[usp_CreateReservationWithPayment] TO [TravelAgent];
GRANT EXECUTE ON [dbo].[usp_CancelReservation] TO [TravelAgent];
GRANT SELECT ON [dbo].[Tour] TO [TravelAgent];
GRANT SELECT ON [dbo].[Client] TO [TravelAgent];
GRANT INSERT ON [dbo].[Client] TO [TravelAgent];
GRANT UPDATE ON [dbo].[Client] TO [TravelAgent];
GRANT SELECT ON [dbo].[Reservation] TO [TravelAgent];
GRANT SELECT ON [dbo].[Payment] TO [TravelAgent];
GO

ALTER ROLE [db_owner] ADD MEMBER [TravelManager];
ALTER ROLE [db_datareader] ADD MEMBER [TravelViewer];
ALTER ROLE [TravelAgent] ADD MEMBER [AgentJohn];
GO


---------------------------------------------------------------------------------------
-- 12. MODEL ODZYSKIWANIA, BACKUP I RESTORE
---------------------------------------------------------------------------------------
ALTER DATABASE [TravelAgencyDB]
SET RECOVERY FULL;
GO

/*
-- Przykładowy pełny backup:
BACKUP DATABASE [TravelAgencyDB]
TO DISK = 'C:\Backup\TravelAgencyDB_FULL.bak'
WITH INIT, NAME='Full backup of TravelAgencyDB';
GO

-- Przykładowy restore:
USE [master];
GO
RESTORE DATABASE [TravelAgencyDB_Restore]
FROM DISK = 'C:\Backup\TravelAgencyDB_FULL.bak'
WITH MOVE 'TravelAgencyDB'     TO 'C:\Data\TravelAgencyDB_Restore.mdf',
     MOVE 'TravelAgencyDB_log' TO 'C:\Data\TravelAgencyDB_Restore_log.ldf',
     REPLACE;
GO
*/


---------------------------------------------------------------------------------------
-- 13. TESTY I SPRAWDZANIE SPÓJNOŚCI
---------------------------------------------------------------------------------------
/*
   Poniższe polecenia służą do zweryfikowania poprawności działania procedur i widoków.
   Można je uruchamiać krok po kroku, obserwując komunikaty i wyniki.
*/

-- 13.1 PODGLĄD TABEL I WIDOKÓW
SELECT * FROM [dbo].[Reservation];
SELECT * FROM [dbo].[Payment];
SELECT * FROM [dbo].[ReservationAmenity];
SELECT * FROM [dbo].[vw_ReservationSummary];
SELECT * FROM [dbo].[vw_UpcomingToursAvailability];

-- 13.2 TEST usp_ConfirmReservation
-- Potwierdzamy rezerwację 1 (Złożoną), dopłacając 100.00 gotówką (PaymentMethodID=3)
EXEC [dbo].[usp_ConfirmReservation]
    @ReservationID   = 1,
    @PaymentMethodID = 3,     -- "Gotówka"
    @PaymentAmount   = 100.00;

-- Sprawdzamy:
SELECT * FROM [dbo].[Reservation]         WHERE ReservationID = 1;
SELECT * FROM [dbo].[Payment]             WHERE ReservationID = 1;
SELECT * FROM [dbo].[vw_ReservationSummary] WHERE ReservationID = 1;

-- 13.3 TEST usp_ChangeNumberOfPeople
-- Zmieniamy z 2 -> 4 (o ile są wolne miejsca)
EXEC [dbo].[usp_ChangeNumberOfPeople]
    @ReservationID      = 1,
    @NewNumberOfPeople  = 4;

SELECT * FROM [dbo].[Reservation]          WHERE ReservationID = 1;
SELECT * FROM [dbo].[vw_ReservationSummary] WHERE ReservationID = 1;

-- 13.4 TEST usp_AddAmenityToReservation
-- Dodajemy AmenityID=2 ("Transfer z lotniska") do rezerwacji 1
EXEC [dbo].[usp_AddAmenityToReservation]
    @ReservationID = 1,
    @AmenityID     = 2;

SELECT * FROM [dbo].[ReservationAmenity] 
WHERE ReservationID = 1;

-- 13.5 TEST usp_UpdateAmenityPriceInReservation
-- Najpierw sprawdzamy ReservationAmenityID (np. 2, 3?) dla (ReservationID=1, AmenityID=2)
SELECT * FROM [dbo].[ReservationAmenity]
WHERE ReservationID = 1 AND AmenityID = 2;

EXEC [dbo].[usp_UpdateAmenityPriceInReservation]
    @ReservationAmenityID = 2,
    @NewPrice             = 85.00;   -- Nowa cena

-- 13.6 TEST usp_GetReservationDetails
EXEC [dbo].[usp_GetReservationDetails]
    @ReservationID = 1;

-- 13.7 TEST usp_CancelReservation
EXEC [dbo].[usp_CancelReservation]
    @ReservationID = 1;

-- Potwierdzenie, że status = Anulowana
SELECT * FROM [dbo].[Reservation] WHERE ReservationID = 1;

-- Próba zmiany liczby osób -> powinna zwrócić błąd
EXEC [dbo].[usp_ChangeNumberOfPeople]
    @ReservationID     = 1,
    @NewNumberOfPeople = 5;

