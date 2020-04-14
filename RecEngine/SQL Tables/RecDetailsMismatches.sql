USE [RecEngine]
GO

/****** Object:  Table [Report].[RecDetailsMismatches]    Script Date: 14/04/2020 10:09:22 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [Report].[RecDetailsMismatches](
	[RecName] [nvarchar](255) NULL,
	[RecTable] [nvarchar](255) NULL,
	[TargetTable] [nvarchar](255) NULL,
	[PrimaryKey] [nvarchar](255) NULL,
	[ColumnName] [nvarchar](255) NULL,
	[ColumnValue_Source] [nvarchar](max) NULL,
	[ColumnValue_Target] [nvarchar](max) NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO


