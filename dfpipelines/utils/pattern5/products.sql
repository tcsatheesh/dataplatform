CREATE TABLE dbo.products
(
    ID int NOT NULL,
    Name varchar(50),
    Type varchar(50),
	Description varchar(250)
)
GO

CREATE CLUSTERED INDEX IX_products_ID ON dbo.products (ID);