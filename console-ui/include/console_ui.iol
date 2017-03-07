type YesNoPromptRequest: string {
    .defaultValue?: bool
}

type FormatRequest: string {
    .args[0, *]: undefined
}

type RepeatRequest: void {
    .char: string
    .count: int
}

interface ConsoleUIIface {
  RequestResponse:
     readLine(void)(string),
     hasNextLine(void)(bool),
     displayPrompt(string)(string),
     displayYesNoPrompt(YesNoPromptRequest)(bool),
     displaySpinner(void)(void),
     stopSpinner(void)(void),
     readPassword(void)(string),
     displayPasswordPrompt(string)(string),
     createColoredMessage(string)(string),
     printColoredMessage(string)(void),
     format(FormatRequest)(string),
     formatc(FormatRequest)(string),
     printf(FormatRequest)(void),
     printfc(FormatRequest)(void),
     repeat(RepeatRequest)(string)
}

outputPort ConsoleUI {
    Interfaces: ConsoleUIIface
}

embedded {
  Java: "dk.thrane.jolie.ConsoleUI" in ConsoleUI
}
