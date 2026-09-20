# Finding and Fixing a Command Injection Vulnerability in an ASP.NET Web App

## Lab Overview

Command injection is one of the oldest and most dangerous classes of web vulnerability,
and it turns up whenever an application takes something a user typed and hands it to the
operating system to run. When that happens, the search box you built for your users
quietly becomes a command prompt for your attackers.

Two things have to line up for this to be exploitable. First, the application has to
accept input that an attacker can control. Second, that input has to reach a system
shell without being sanitized or safely separated from the command around it. When both
are true, an attacker can stop searching for files and start running anything they like
on your server, with whatever privileges your application happens to have.

That is exactly what happened to Globomantics. The notorious hacking group **Dark
Kittens** breached the artificial island in the Gulf of Mexico where Globomantics is
building the infrastructure for its "ideal society," and the investigation traced the
intrusion back to the file search feature of an internal ASP.NET Core application. In
this lab you are on the blue team. You will confirm the flaw the way Dark Kittens did,
understand exactly why it works, fix it at the root, and then throw the same attack at
your fix to prove it holds.

## Learning Objectives

By the end of this lab you will be able to:

* Recognize the code pattern that leads to an **OS command injection** vulnerability
  (CWE-78) in a .NET application.
* Explain *why* handing user input to a shell interpreter is so dangerous.
* Confirm the vulnerability the way an attacker would, by crafting and running a payload.
* Remediate the flaw by removing the shell from the code path entirely.
* Verify that the fix defeats the same attack that worked a moment earlier.

## Recommended Prerequisites

None of this is required, but it will help:

* A little C#, and a rough idea of how an ASP.NET Core controller handles a request.
* Comfort running commands in a Linux terminal.
* Familiarity with the idea of a shell such as Bash, and the special characters it
  treats as command separators, like `;` and `|`.

## Before You Begin

Everything in this lab happens inside a single Ubuntu virtual machine. It already has
the .NET SDK, Visual Studio Code, and Firefox installed, and the Globomantics project is
waiting on the Desktop. You will not install anything or switch machines.

Out of the whole project, there is exactly one file you
need to touch, and it is `Controllers/HomeController.cs`. Everything else is standard
ASP.NET Core scaffolding. If you find yourself wandering into the `Views` or `wwwroot`
folders, you have gone too far.

## Task 1: Get the Application Running

You cannot defend an application you have never seen run, and you certainly cannot tell
whether your fix worked if you never watched the attack succeed first. So before you
touch a line of code, let's get the Globomantics web app up and reach the feature that Dark Kittens abused.

### Step 1: Open the project in Visual Studio Code

Launch **Visual Studio Code**, then open the project folder at
`/home/pslearner/Desktop/lab_security-lab-audition-example`.

> **Note**
> Think of this as sitting down at the desk of the Globomantics developer who wrote this
> web app. Open the whole folder rather than a single file, because that gives Visual Studio
> Code the correct project context where the integrated terminal will start in the right
> place, and the C# tooling can make sense of the code you are about to read.

> **Analysis**
> Glance at the Explorer pane on the left. In an ASP.NET Core MVC project, the
> **Controllers** folder holds the logic that runs on the server when a request comes
> in, and the **Views** folder holds the pages the user sees. The vulnerability you are
> trying to discover lives in a controller, so that is where you will be spending your time.

### Step 2: Open an integrated terminal

From the menu bar, select **Terminal > New Terminal**.

> **Note**
> A developer on the Globomantics team would build and run the app from a terminal
> exactly like this one, so that is what you will do too. Because you opened the project
> as a folder, this terminal already starts inside the project directory.

> **Analysis**
> Confirm the prompt shows you are inside the `lab_security-lab-audition-example` folder.
> This matters because the web app searches for a folder called `docs` using a
> relative path, so if you ran it from somewhere else, that path would point at the wrong
> place and nothing would work.

### Step 3: Start the application

In the terminal, run the following command:

```bash
dotnet run
```

> **Note**
> `dotnet run` quietly does three jobs in one command. It **restores** the project's
> NuGet dependencies, **compiles** the C# into a runnable program, and then **starts**
> the Kestrel web server that hosts it. This one command is how .NET developers spin up a
> web app while they work.

> **Analysis**
> Watch for a line like `Now listening on: http://localhost:5265`. That is the Kestrel web server
> telling you the app is live and waiting for requests. Jot down the exact port it shows
> you, because you will need it in a second. It is not random, by the way. It comes from
> `Properties/launchSettings.json`, so it will be the same every time you run this
> project.

### Step 4: Open the application in the browser

Open **Firefox**, go to the address from the previous step (for example,
`http://localhost:5265`), and click the **Search Files** link in the top navigation bar.

> **Note**
> This unassuming little page is the scene of the crime. It is meant to do one friendly
> thing: let someone type part of a filename and see which documents in the server's
> `docs` folder match.

> **Analysis**
> Take a good look, because this is the entire attack surface: one text box whose value
> gets sent to the server and used in a file search. Any time input from a user reaches
> code running on the server, a security professional's first instinct should be to ask,
> "what happens to my input once it gets there?" The rest of this lab answers that
> question, and you are not going to like the answer.

## Task 2: See It Work, Then See It Break

The best way to understand a vulnerability is to watch the feature behave, read the code
that makes it behave, and then use that code against itself. That is the arc of this
task.

### Step 5: Do a normal, honest search

In the **Search Files** box, type the following and click **Search**:

```
test.txt
```

> **Note**
> This is the search a real user would run, and the "happy path" the developer had in
> mind. The project ships with one sample document, `docs/test.txt`, so you are asking
> for something that actually exists.

> **Analysis**
> Under **Search Results** you should see the path to `test.txt` come back. That tells
> you something important, that the feature works by matching your input against real files on
> the server. Hold on to this picture of normal behavior, because in two steps you are
> going to make this same box do something it was never meant to do, and you will only
> recognize the difference because you saw normal first.

### Step 6: Read the code and find out why this is dangerous

In the Explorer, open `Controllers/HomeController.cs` and find the `Search` action
method:

```csharp
[HttpGet]
public IActionResult Search(string filename)
{
    if (filename is not null)
    {
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
    }
    else
    {
        return View();
    }
}
```

> **Note**
> Read this the way the server runs it. Instead of searching for files itself, the app
> builds a command as a piece of text and asks Bash to run it. Walk the `Arguments` line
> from the inside out:
>
> * `FileName = "/bin/bash"` means the program being launched is the **Bash shell
>   itself**. That is the whole ballgame right there.
> * `-c "..."` tells Bash, "run the string that follows as a command."
> * `find ./docs -type f -name *{filename}` is the command the developer intended: search
>   `docs` for files whose name matches what the user typed.
> * `$"...{filename}..."` is C# **string interpolation**. Whatever the user typed gets
>   dropped straight into that command text, with nothing checking it and nothing
>   escaping it.

> **Analysis**
> There is the root cause, and it is worth saying out loud. The user's input is not being
> treated as *data*, a harmless value to search for. It is being pasted into a string
> that Bash will read *as commands*. And Bash, being a shell, treats characters like `;`,
> `|`, and `&&` as "one command ends, another begins." So anyone who types those
> characters into your search box gets to tack their own command onto yours. That is the
> textbook definition of **OS command injection (CWE-78)**. One thing that trips people
> up: `UseShellExecute = false` sounds like a safety setting, but it does nothing for you
> here, because you are the one deliberately launching a shell as the program.

### Step 7: Prove it, the way Dark Kittens did

Go back to Firefox, clear the search box, type this payload, and click **Search**:

```
test.txt; whoami
```

> **Note**
> Every character in that payload is doing a job, and it lines up perfectly with the code
> you just read:
>
> * `test.txt` is the innocent part, the filename the app expects. This is the culprit.
> * `;` is the key that unlocks the door. To Bash it means "that command is finished,
>   here comes another one."
> * `whoami` is the smuggled command. It has nothing to do with searching files. It
>   just prints the operating system user the app is running as, which is an attacker's
>   polite way of asking "who am I, and how much damage can I do from here?"
>
> When the server stitches its command together, your input has turned it into
> `find ./docs -type f -name *test.txt; whoami`. The `find` runs, and then, because of
> that semicolon, so does `whoami`.

> **Analysis**
> Now look at the results, and notice you got back *two* things. The path to `test.txt`
> from the intended search, and underneath it, a username like `pslearner`. That second
> line is the entire point. You did not search for a file named `pslearner`. You ran a
> command. And here is the part that should pay attention because if
> `whoami` runs, then so does `cat /etc/passwd`, or a command that opens a reverse shell,
> or `rm -rf`. `whoami` is harmless, but it is proof that the door is wide open. This is
> the exact move that took Dark Kittens from "searching a file" to "owning the server."

## Task 3: Shut the Door

You have seen it work. Now you get to be the one who fixes it, and there is a right way
and a tempting wrong way to do that. This task takes the right one.

### Step 8: Replace the shell call with a native .NET search

In `Controllers/HomeController.cs`, replace the entire `Search` action method with this:

```csharp
[HttpGet]
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

Save the file.

> **Note**
> The tempting fix is to blacklist the dangerous characters and strip them out. Resist
> it. Filtering is a losing game, and attackers are very good at playing it. The
> real fix is to take away the thing that gave those characters power in the first place which is
> the shell. `Directory.GetFiles` is a native .NET method that searches a folder
> directly through the operating system's file API. There is no Bash, no `-c`, no command
> string for anyone to hijack. Your `filename` is now used *only* as a pattern to match
> filenames against, and to that API, `;` and `|` are just ordinary characters in a
> search term that happens to match nothing.

> **Analysis**
> Sit with the difference for a second, because it is the whole lesson. The old code
> asked a *shell* to run a search, which meant the shell was free to interpret whatever
> got mixed in. The new code asks the *.NET framework* to run a search, and the framework
> has no notion of "run this as a command." Same feature, identical results for the honest
> user in Step 5, but the attacker's separators now have nowhere to be interpreted. You
> have now removed the hole.

### Step 9: Restart the application

Back in the terminal, if the app is still running, press `Ctrl + C` to stop it, then run
it again:

```bash
dotnet run
```

> **Note**
> The server compiled your code when it started, which means the copy running right now
> is still the *old, vulnerable* version. Your fix does not exist until you stop and start
> the app again. This is a step usually forgotten, so it is a good habit to build now.

> **Analysis**
> Wait for that `Now listening on:` line again. The app is back, this time carrying your
> remediated `Search` method. Everything is set for the satisfying part, which is watching
> the attack that just worked fall flat.

### Step 10: Throw the exact same attack at your fix

In Firefox, browse to the running app again, open **Search Files**, and enter the *same*
payload as before:

```
test.txt; whoami
```

> **Note**
> Reusing the identical payload is an essential part of a disciplined security testing. A fix
> that has not been validated against the specific attack it was intended to prevent cannot be 
> considered a confirmed fix. The right approach is to reproduce the actual attack and verify that > the remediation effectively prevents it.

> **Analysis**
> And this time, nothing. No `pslearner` line, no smuggled command, no surprise. Your
> whole input, semicolon and all, is now just literal text. The framework goes looking for
> a file whose name contains `test.txt; whoami`, finds none, and i disregarded. The command never
> runs. The door Dark Kittens walked through is closed, and you closed it not by guessing
> at bad characters but by refusing to let a shell see user input at all.

## Task 4: Go Further

You solved the problem. Before you close the lab, spend a few minutes proving to yourself
that you really understand it, because the best way to trust a defense is to attack it
from a few angles.

### Step 11: Experiment on your own

The environment is yours. Try a few of these, and pay attention to *why* each one behaves
the way it does:

* Paste the original vulnerable method back in, restart, and try `test.txt; id` or
  `test.txt; cat /etc/passwd`. Watch how much an attacker can pull back through a search
  box once a shell is in the loop.
* On that vulnerable version, swap the `;` for `|` or `&&` and confirm they all work. Then
  switch to your fixed version and confirm every one of them fails. Seeing multiple
  payloads fail against a single fix is what "fixing the root cause" really means.

> **Note**
> Zoom out, because this lesson is much bigger than one search box. **Injection bugs show
> up anywhere untrusted input gets mixed into something that then gets interpreted**,
> whether that interpreter is a shell, a SQL database, an LDAP directory, or a browser
> rendering HTML. The robust defense is almost always the same form you used in this lab and that 
> is to keep code and data apart, and use APIs or parameterized interfaces that treat user input
> strictly as data and never as instructions.

> **Analysis**
> Removing the shell was the correct primary fix, but a defender thinking in layers would
> not stop there. In a production Globomantics app you would also validate and allowlist
> the search input so only sensible filename characters get through, run the web process
> with the least privilege it can get away with so any future flaw does less damage, and
> pin the search to a specific directory so nobody can traverse the filesystem. If you want
> to keep going, OWASP's writeup on Command Injection is the classic next read, and on the
> Pluralsight platform this lab pairs naturally with a secure coding path. 