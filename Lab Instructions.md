# Mitigating Command Injection Vulnerability in ASP.NET Web App

## Lab Description
In this challenge, you will identify and remediate a command injection vulnerability in an ASP.NET web application.

The notorious hacking group Dark Kittens has struck again! Who are they? What do they want? And how are they so good? Globomantics runs an artificial island in the Gulf of Mexico, attempting to build an infrastructure for the "ideal society." They have fallen victim to repeated attacks and have issued an international bounty for anyone willing to take these hackers down. You will go on the defense: take on the role of Globomantics, realizing you have to mitigate the attacks on your ASP.NET web app, which is part of the "ideal society" infrastructure where Dark Kittens was discovered exploiting its command injection vulnerability.

## Steps

1. **Open the Project in Visual Studio Code:**
   - Launch **Visual Studio Code** from the dock or start menu.
   - Open the project folder located at `/home/pslearner/Desktop`.

2. **Identify the Vulnerable Code:**
   - Navigate to the `HomeController.cs` file located in the `Controllers` folder.
   - Locate the `Search` action method which contains the following code:
     ```csharp
      var process = new Process
      {
            StartInfo = new ProcessStartInfo
            {
               FileName = "/bin/bash",
               Arguments = $" -c \"find ./docs -type f -name *{filename}\"",
               RedirectStandardOutput = true,
               UseShellExecute = false
            }
      };
      process.Start();
      string output = process.StandardOutput.ReadToEnd();
      process.WaitForExit();
      ViewBag.Output = output;
      return View("Search");
    ```

3. **Understand the Vulnerability:**
   - The `filename` parameter is directly concatenated into the command line arguments, making the application vulnerable to command injection attacks. An attacker could inject malicious commands through the `filename` parameter.

4. **Validate the vulnerability:**
   - Open a new terminal in **Visual Studio Code** by clicking `Terminal`->`New Terminal`.
   - In the terminal, type `dotnet run` to start the application  
   - Navigate to the `http://localhost:5172/` and click the `Search Files` bread crumb
   - In the search box enter `test.txt`, notice the search result below the page
   - Now clear the search box and enter the command injection payload `test.txt|netstat`.   
   - Verify that the injected `netstat` command executes unexpectedly and that the vulnerability exists.

5. **Remediate the Vulnerability:**
   - Replace the direct command execution with a safer approach. Use the `Directory.GetFiles` method native to the .NET framework to search for files instead of executing a shell command.
   - Update the `Search` action method as follows:
     ```csharp
     public IActionResult Search(string filename)
     {
         if (filename is not null)
         {
            var files = Directory.GetFiles("./docs", $"*{filename}*");
            var output = string.Join("\n", files);
            ViewBag.Output = output;
            return View("Search");
         }
         else
         {
             return View();
         }
     }
     ```

6. **Test the Remediation:**
   - Save the changes and run the application with the `dotnet run` command in the Terminal.
   - Navigate to the `http://localhost:5172/` and click the `Search Files` bread crumb
   - In the search box enter the payload `test.txt|netstat`
   - Verify that the search functionality works as expected and that the command injection vulnerability is mitigated.

7. **Conclusion:**
   - By replacing the direct command execution with a safer method, you have successfully mitigated the command injection vulnerability in the ASP.NET web application.
   - This remediation prevents the notorious hacking group Dark Kittens from injecting malicious commands through the `filename` parameter, enhancing the security of the application.

In the next lab, we'll continue to strengthen the security of the application by implementing additional validation and sanitization techniques.

