USE [master]
GO
CREATE DATABASE [tpce] ON 
( FILENAME = N'$(drive):\TPCE_Data\MSSQL_tpce_root.mdf' ),
( FILENAME = N'$(drive):\TPCE_Log\TPCE_Log.ldf' ),
( FILENAME = N'$(drive):\TPCE_Data\Fixed_1.ndf' ),
( FILENAME = N'$(drive):\TPCE_Data\Scaling_1.ndf' ),
( FILENAME = N'$(drive):\TPCE_Data\Scaling_2.ndf' ),
( FILENAME = N'$(drive):\TPCE_Data\Scaling_3.ndf' ),
( FILENAME = N'$(drive):\TPCE_Data\Scaling_4.ndf' ),
( FILENAME = N'$(drive):\TPCE_Data\Growing_1.ndf' ),
( FILENAME = N'$(drive):\TPCE_Data\Growing_2.ndf' ),
( FILENAME = N'$(drive):\TPCE_Data\Growing_3.ndf' ),
( FILENAME = N'$(drive):\TPCE_Data\Growing_4.ndf' )
 FOR ATTACH
GO