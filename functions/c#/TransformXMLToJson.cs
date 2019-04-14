using System.IO;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using Microsoft.WindowsAzure.Storage;
using Microsoft.WindowsAzure.Storage.Blob;
using System.Xml;
using System.Collections.Generic;

namespace itdplt.function
{
    public class IncomingMessage
    {
        public string itemName;
    }

    public static class TransformXMLToJson
    {
        [FunctionName("TransformXMLToJson")]
        public static async Task<IActionResult> Run(
            [HttpTrigger(AuthorizationLevel.Function, "get", "post", Route = null)] HttpRequest req,
            ILogger log)
        {
            log.LogInformation("C# HTTP trigger function processed a request.");

            string requestBody = await new StreamReader(req.Body).ReadToEndAsync();
            IncomingMessage im = JsonConvert.DeserializeObject<IncomingMessage>(requestBody);

            log.LogInformation("Request Body: {requestBody}", requestBody);

            string storageConnectionString = System.Environment.GetEnvironmentVariable("dia-stor-connection-string");
            log.LogInformation("Con" + storageConnectionString);
            ProcessAsync(storageConnectionString, im.itemName, log).GetAwaiter().GetResult();
            ProcessAsync(storageConnectionString, im.itemName.Replace("_pmc.xml", "_mort.xml"), log).GetAwaiter().GetResult();
            return new OkObjectResult(new { Result = "OK" });
        }

        public static async Task ProcessAsync(string storageConnectionString, string itemName, ILogger log)
        {
            CloudStorageAccount storageAccount = null;
            CloudBlobContainer cloudBlobContainer = null;
            log.LogInformation("Item Name: {itemName}", itemName);

            // Check whether the connection string can be parsed.
            if (CloudStorageAccount.TryParse(storageConnectionString, out storageAccount))
            {
                CloudBlobClient cloudBlobClient = storageAccount.CreateCloudBlobClient();
                string containerName = itemName.Substring(0, itemName.IndexOf("/"));
                log.LogInformation("Container Name: {containerName}", containerName);
                cloudBlobContainer = cloudBlobClient.GetContainerReference(containerName);
                string blobName = itemName.Substring(itemName.IndexOf("/") + 1);
                log.LogInformation("Blob Name: {blobName}", blobName);
                CloudBlockBlob blockBlob = cloudBlobContainer.GetBlockBlobReference(blobName);
                string xmlFileName = Path.GetTempFileName();
                await blockBlob.DownloadToFileAsync(xmlFileName, FileMode.Create);

                XmlDocument doc = new XmlDocument();
                doc.Load(xmlFileName);

                string jsonFileName = blobName.Replace(".xml", ".json");
                log.LogInformation("Json File Name: {jsonFileName}", jsonFileName);

                string json = JsonConvert.SerializeXmlNode(doc);
                dynamic jsonDocument = JObject.Parse(json);
                jsonDocument.id = doc.SelectSingleNode("//policy/id").InnerText;
                json = jsonDocument.ToString();

                blockBlob = cloudBlobContainer.GetBlockBlobReference(jsonFileName);
                await blockBlob.UploadTextAsync(json);
            }
            else
            {
                log.LogInformation("Failed parsing storageConnectionString: {storageConnectionString} ", storageConnectionString);
            }
        }
    }
}
