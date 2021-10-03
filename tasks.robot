# +
*** Settings ***
Documentation   Orders robots from RobotSpareBin Industries Inc.
...               Saves the order HTML receipt as a PDF file.
...               Saves the screenshot of the ordered robot.
...               Embeds the screenshot of the robot to the PDF receipt.
...               Creates ZIP archive of the receipts and the images.
Library         RPA.Browser.Selenium
Library         RPA.HTTP
Library         RPA.Excel.Files
Library         RPA.Tables
Library         RPA.Robocorp.Vault
Library         RPA.PDF
Library         RPA.Archive
Library         RPA.Dialogs

Suite Teardown  Close All Browsers
# -


*** Variables ***
${OUTPUT_DIRECTORY} =    ${CURDIR}${/}output
${site_url} =   https://robotsparebinindustries.com/#/robot-order
${excel_url}=   https://robotsparebinindustries.com/orders.csv
${GLOBAL_RETRY_AMOUNT}=    5x
${GLOBAL_RETRY_INTERVAL}=    2s
${GLOBAL_SLEEP} =   2s

*** Tasks ***
Minimal task
    Log  Done.

*** Keywords ***
Collect Excel File From User
     Add text input    excelurl    label=Please input your input csv    
     ${response}=    Run dialog
     Log    You are selecting ${response.excelurl}
     [Return]    ${response.excelurl}

*** Keywords ***
Open the robot order website
    Open Available Browser    ${site_url}

*** Keywords ***
Read Credential
    ${secret}=    Get Secret    credentials_test
    Log    You are using ${secret}[username]
    [return]    ${secret}

*** Keywords ***
Get orders
    Download    ${excel_url}      overwrite=True    
    ${orders}=  Read table from CSV    orders.csv
    Log           Found columns: ${orders.columns}    
    [Return]    ${orders}
    [Teardown]  Close workbook

*** Keywords ***
Close the annoying modal
    Click Button    class:btn.btn-dark

*** Keywords ***
Fill the form 
    [Arguments]     ${myRow}
    Log    ${myRow}
    Select From List By Index    //*[@id='head']    ${myRow}[Head]    
    Select Radio Button          body    ${myRow}[Body]
    Input Text                   //*[@placeholder="Enter the part number for the legs"]    ${myRow}[Legs]
    input Text                   //*[@id='address']      ${myRow}[Address]

*** Keywords ***
Preview the robot
    Click Button        //*[@id="preview"]
    Sleep               ${GLOBAL_SLEEP}
    Log                 completed preview

*** Keywords ***
Submit the order
    Click Button    //*[@id="order"]
    Sleep           ${GLOBAL_SLEEP}
    Wait Until Element Is Visible    id:receipt
    Log             completed preview

*** Keywords ***
Go to order another robot
    Click Button    //*[@id="order-another"]

*** Keywords ***
Store the receipt as a PDF file    
    [Arguments]     ${orderNumber}
    Wait Until Element Is Visible   id:receipt
    ${receipt}=    Get Element Attribute     id:receipt     outerHTML
    Html To Pdf    ${receipt}    ${OUTPUT_DIRECTORY}${/}${orderNumber}.pdf
    [Return]    ${OUTPUT_DIRECTORY}${/}${orderNumber}.pdf

*** Keywords ***
Take a screenshot of the robot
    [Arguments]     ${orderNumber}
    ${screenshot}=      Screenshot    //*[@id="robot-preview-image"]   ${OUTPUT_DIRECTORY}${/}${orderNumber}.png
    [Return]    ${OUTPUT_DIRECTORY}${/}${orderNumber}.png

*** Keywords ***
Embed the robot screenshot to the receipt PDF file    
    [Arguments]     ${screenshot}    ${pdf}
    Log     screenshot is ${screenshot}
    Log     pdf is ${pdf}
    ${file} =    Create List    ${screenshot}
    Add Files To Pdf    ${file}   ${pdf}  TRUE

*** Keywords ***
Create a ZIP file of the receipts
    Archive Folder With ZIP   ${OUTPUT_DIRECTORY}   ${OUTPUT_DIRECTORY}${/}tasks.zip   recursive=True  include=*.pdf  exclude=/.*
    Remove Files    ${OUTPUT_DIRECTORY}${/}*.pdf
    Remove Files    ${OUTPUT_DIRECTORY}${/}*.png

*** Tasks ***
Order robots from RobotSpareBin Industries Inc
    Open the robot order website
    Read Credential
    Collect Excel File From User
    ${orders}=    Get orders
    FOR    ${row}    IN    @{orders}
        Close the annoying modal
        Fill the form    ${row}
        Preview the robot
        Wait Until Keyword Succeeds     
        ...    ${GLOBAL_RETRY_AMOUNT}      
        ...    ${GLOBAL_RETRY_INTERVAL}           
        ...    Submit the order
        ${pdf}=    Store the receipt as a PDF file    ${row}[Order number]
        ${screenshot}=    Take a screenshot of the robot    ${row}[Order number]
        Embed the robot screenshot to the receipt PDF file    ${screenshot}    ${pdf}
        Go to order another robot
        #Exit For Loop
    END
    Create a ZIP file of the receipts
    #[Teardown]  Close Browser
