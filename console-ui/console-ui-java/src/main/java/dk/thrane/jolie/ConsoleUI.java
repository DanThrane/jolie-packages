package dk.thrane.jolie;

import jolie.runtime.JavaService;
import jolie.runtime.Value;
import jolie.runtime.ValueVector;
import jolie.runtime.embedding.RequestResponse;
import org.fusesource.jansi.AnsiConsole;

import static org.fusesource.jansi.Ansi.*;

import java.util.*;
import java.util.stream.Collectors;
import java.util.stream.Stream;
import java.util.stream.StreamSupport;

public class ConsoleUI extends JavaService {
    private final Scanner scanner = new Scanner(System.in);
    private Thread spinnerThread = null;
    private boolean spinnerThreadSuspended = false;

    public ConsoleUI() {
        AnsiConsole.systemInstall();
    }

    @RequestResponse
    public String readLine() {
        return scanner.nextLine();
    }

    @RequestResponse
    public boolean hasNextLine() {
        return scanner.hasNextLine();
    }

    @RequestResponse
    public String displayPrompt(Value request) {
        String message = request.strValue();
        @SuppressWarnings("SimplifiableConditionalExpression")
        boolean boldText = request.hasChildren("bold") ? request.getFirstChild("bold").boolValue() : true;
        @SuppressWarnings("SimplifiableConditionalExpression")
        boolean border = request.hasChildren("border") ? request.getFirstChild("border").boolValue() : true;
        String prompt = request.hasChildren("prompt") ? request.getFirstChild("prompt").strValue() : "> ";

        String formattedMessage = message;
        if (boldText) {
            formattedMessage = "@|bold " + formattedMessage + "|@";
        }

        System.err.println(createColoredMessage(formattedMessage));

        if (border) {
            char[] borderTextA = new char[message.length()];
            Arrays.fill(borderTextA, '-');
            String borderText = new String(borderTextA);
            if (boldText) {
                borderText = "@|bold " + borderText + "|@";
                borderText = createColoredMessage(borderText);
            }
            System.err.println(borderText);
        }
        System.err.print(prompt);
        System.err.flush();

        String result = readLine();
        System.err.println();
        return result;
    }

    @RequestResponse
    public Value displayYesNoPrompt(Value request) {
        String message = request.strValue();
        @SuppressWarnings("SimplifiableConditionalExpression")
        boolean boldText = request.hasChildren("bold") ? request.getFirstChild("bold").boolValue() : true;
        @SuppressWarnings("SimplifiableConditionalExpression")
        boolean border = request.hasChildren("border") ? request.getFirstChild("border").boolValue() : true;
        String prompt = request.hasChildren("prompt") ? request.getFirstChild("prompt").strValue() : "> ";

        Value val = request.getFirstChild("defaultValue");

        @SuppressWarnings("SimplifiableConditionalExpression")
        boolean defaultValue = (val.isDefined() && val.isBool()) ? val.boolValue() : true;

        String formattedMessage = message;
        if (boldText) {
            formattedMessage = "@|bold " + formattedMessage + "|@";
        }

        String borderText = null;
        if (border) {
            char[] borderTextA = new char[message.length() + 6];
            Arrays.fill(borderTextA, '-');
            borderText = new String(borderTextA);
            if (boldText) {
                borderText = "@|bold " + borderText + "|@";
                borderText = createColoredMessage(borderText);
            }
        }

        while (true) {
            System.err.print(createColoredMessage(formattedMessage));
            System.err.print(" ");
            if (defaultValue) {
                System.err.print("[Y/n]");
            } else {
                System.err.print("[y/N]");
            }
            System.err.println();
            if (border) {
                System.err.println(borderText);
            }
            System.err.print(prompt);
            System.err.flush();

            String line = readLine();
            Boolean value = null;
            boolean defaultTriggered = line.length() == 0;
            if (line.equalsIgnoreCase("y") || (defaultTriggered && defaultValue)) {
                value = true;
            } else if (line.equalsIgnoreCase("n") || (defaultTriggered && !defaultValue)) {
                value = false;
            }

            if (value != null) {
                Value result = Value.create(value);
                System.err.println();
                return result;
            } else {
                System.err.println("Unknown value.");
            }
        }
    }

    private void safeSleep(long ms) {
        try {
            Thread.sleep(ms);
        } catch (InterruptedException ignored) {
        }
    }

    @RequestResponse
    public void displaySpinner() {
        if (spinnerThread == null) {
            spinnerThread = new Thread(() -> {
                System.err.print("/");
                while (!spinnerThreadSuspended) {
                    System.err.print("\b-");
                    System.err.flush();
                    safeSleep(150);
                    if (spinnerThreadSuspended) break;
                    System.err.print("\b\\");
                    System.err.flush();
                    safeSleep(150);
                    if (spinnerThreadSuspended) break;
                    System.err.print("\b/");
                    System.err.flush();
                    safeSleep(150);
                }
                System.err.print("\b");
                System.err.flush();
                spinnerThreadSuspended = false;
                spinnerThread = null;
            });
            spinnerThread.start();
        }
    }

    @RequestResponse
    public void stopSpinner() {
        if (spinnerThread != null) {
            spinnerThread.interrupt();
        }
        spinnerThreadSuspended = true;
    }

    @RequestResponse
    public String readPassword() {
        return new String(System.console().readPassword());
    }

    @RequestResponse
    public String displayPasswordPrompt(String message) {
        System.err.println(createColoredMessage(message) + ":");
        return readPassword();
    }

    @RequestResponse
    public String createColoredMessage(String message) {
        return ansi().render(message).toString();
    }

    @RequestResponse
    public void printColoredMessage(String message) {
        System.err.println(createColoredMessage(message));
    }

    @RequestResponse
    public String format(Value request) {
        String format = request.strValue();
        List<Object> args = valueStream(request.getChildren("args"))
                .map(Value::valueObject)
                .collect(Collectors.toList());

        Object[] args1 = args.toArray();
        return String.format(format, (Object[]) args1);
    }

    @RequestResponse
    public String repeat(Value request) {
        char aChar = request.getFirstChild("char").strValue().charAt(0);
        int count = request.getFirstChild("count").intValue();

        char[] result = new char[count];
        Arrays.fill(result, aChar);
        return new String(result);
    }

    @RequestResponse
    public String formatc(Value request) {
        return createColoredMessage(format(request));
    }

    @RequestResponse
    public void printf(Value request) {
        System.err.println(format(request));
    }

    @RequestResponse
    public void printfc(Value request) {
        System.err.println(formatc(request));
    }

    private Stream<Value> valueStream(ValueVector vector) {
        Spliterator<Value> spliterator = Spliterators.spliterator(vector.iterator(), vector.size(), 0);
        return StreamSupport.stream(spliterator, false);
    }
}

