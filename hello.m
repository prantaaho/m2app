function outputArg1 = hello(inputArg1,inputArg2)
%HELLO Simple Hello world application
%   Detailed explanation goes here
arguments
    inputArg1 (1,1) string = "Hello";
    inputArg2 (1,1) string = "World!";
end
message = inputArg1 + " " + inputArg2;
uiwait(msgbox(message, "Hello message" , "help", "non-modal"));
outputArg1 = 'Hello';
end

