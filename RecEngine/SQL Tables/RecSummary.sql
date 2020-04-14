USE [RecEngine]
GO

/****** Object:  Table [Report].[RecSummary]    Script Date: 14/04/2020 10:11:12 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [Report].[RecSummary](
	[RecName] [nvarchar](255) NULL,
	[TotalSourceRecords] [bigint] NULL,
	[TotalTargetRecords] [bigint] NULL,
	[Matches] [bigint] NULL,
	[Mismatches] [bigint] NULL,
	[NotExistInSource] [bigint] NULL,
	[NotExistInTarget] [bigint] NULL,
	[ReportRunDate] [datetime] NULL,
	[ReportRuntime(sec)] [int] NULL
) ON [PRIMARY]

GO


