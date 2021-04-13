@isTest(SeeAllData=true)
private class TestSFDataToJSON {    
    @isTest static void TestProduceJSON()
    {
        String contractJSON;
        SFData_To_JSON TestGetJSON = new SFData_To_JSON();
        contractJSON=TestGetJSON.GenerateSFJSON();
        System.debug(contractJSON);
    }
}
