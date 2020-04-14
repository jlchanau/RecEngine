using System;
using System.Data;
using System.Data.SqlClient;
using System.Data.SqlTypes;
using Microsoft.SqlServer.Server;
using System.Security.Cryptography;

public class HashUtil
{
    [SqlFunction(IsDeterministic = true)]
    public static SqlBinary GetHash(SqlString algorithm, SqlBytes src)
    {
        if (src.IsNull)
            return null;

        switch (algorithm.Value.ToUpperInvariant())
        {
            case "MD5":
                return new SqlBinary(MD5.Create().ComputeHash(src.Stream));
            case "SHA1":
                return new SqlBinary(SHA1.Create().ComputeHash(src.Stream));
            case "SHA2_256":
                return new SqlBinary(SHA256.Create().ComputeHash(src.Stream));
            case "SHA2_512":
                return new SqlBinary(SHA512.Create().ComputeHash(src.Stream));
            default:
                throw new ArgumentException("HashType", "Unrecognized hashtype: " + algorithm.Value);
        }
    }
}