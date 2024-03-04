function compile(mainFile, options)
    % COMPILE Compile and create an installer for a MATLAB application
    %
    % Compile, codesign and notarize a MATLAB application.
    % The application is then packaged into an installer and codesigned and notarized.
    %
    % The process follows the documentation at
    % https://se.mathworks.com/matlabcentral/answers/726743-how-can-i-sign-and-notarize-my-compiled-application-to-conform-with-apple-s-notarization-requirement
    
    arguments
        mainFile {mustBeFile};
        options.CodeSignIdentity {mustBeTextScalar} = ""
        options.OutputDir {mustBeTextScalar} = "output";
        options.Name {mustBeTextScalar} = "";
    end
    
    if options.Name == ""
        [~, name, ~] = fileparts(mainFile);
        options.Name = name;
    end
    
    app_path = options.OutputDir + "/" + options.Name + ".app";
    
    
    % Clear the output directory
    if isfolder(options.OutputDir)
        rmdir(options.OutputDir, 's');
    end
    
    % Compiler options
    opts = compiler.build.StandaloneApplicationOptions(...
        mainFile,...
        "EmbedArchive",false,...
        "ExecutableName", options.Name,...
        "OutputDir", options.OutputDir,...
        "Verbose",true);
    
    % Call the compiler.build.standaloneApplication function
    compiler.build.standaloneApplication(opts);
    
    % Codesign the application
    disp("Codesign the application")
    l_codesign(app_path + "/Contents/MacOS/hello", "entitlements.plist", identity=options.CodeSignIdentity);
    l_codesign(app_path + "/Contents/MacOS/applauncher", "entitlements.plist", identity=options.CodeSignIdentity);
    l_codesign(app_path + "/Contents/MacOS/prelaunch", "entitlements.plist", identity=options.CodeSignIdentity);
    l_codesign(app_path, identity=options.CodeSignIdentity);
    
    % Notarize the application
    disp("Notarize the application")
    l_notarize(app_path);
    
    
    % Make installer
    % setenv("DITTONORSRC", 'true');
    disp("Make installer")
    installer_path = l_make_installer(app_path, options.OutputDir);
    disp("Codesign the installer")
    l_codesign(installer_path, "", identity=options.CodeSignIdentity, deep=false);
    disp("Notarize the installer")
    l_notarize(installer_path);
    
    % Done
    disp('DONE')
    
end

function l_codesign(app_path, entitlements, options)
    %CODESIGN Codesign application
    arguments
        app_path {mustBeText}
        entitlements {mustBeTextScalar} = "entitlements.plist"
        options.deep {mustBeNumericOrLogical} = false
        options.identity {mustBeTextScalar} = ""
    end
    
    codesign_opts = "codesign -s " + options.identity + ...
        " --verbose --force --options=runtime";
    
    if options.deep
        codesign_opts = codesign_opts + " --deep";
    end
    
    if ~strcmp(entitlements, "")
        codesign_opts = codesign_opts + " --entitlements=" + entitlements;
    end
    
    if length(app_path) > 1
        app_path = join(app_path, " ");
    end
    l_check_output(codesign_opts + " " + app_path);
    
end

function l_notarize(app_path)
    %NOTARIZE Notarize application
    arguments
        app_path {mustBeFolder}
    end
    
    % Zip it
    disp("+ Zipping " + app_path +" for authorization.")
    zip_path = app_path;
    zip_path = strrep(zip_path, '.app', '.zip');
    
    % Remove old zip package
    if exist(zip_path, 'file')
        delete(zip_path);
    end
    
    l_check_output(sprintf('ditto -c -k --keepParent %s %s', app_path, zip_path));
    
    disp("+ Submitting " + zip_path + " for notarization.")
    cmd_out = l_check_output(...
        sprintf('xcrun notarytool submit %s --keychain-profile "AC_PASSWORD" --wait', zip_path));
    if ~contains(cmd_out, 'Accepted')
        error(cmd_out)
    end
    
    disp("+ Running stapler for " + app_path);
    disp(l_check_output(sprintf('xcrun stapler staple %s', app_path)));
end

function installer_path = l_make_installer(app_full_path, outdir)
    %MAKE_INSTALLER Make installer
    arguments
        app_full_path {mustBeFolder}
        outdir {mustBeTextScalar} = ""
    end
    
    [app_path, app_name, ~] = fileparts(app_full_path);
    installer_name = app_name + '_installer';
    
    installer_path = fullfile(outdir, installer_name + ".app");
    
    if exist(installer_path, 'dir')
        disp('+ Removing old installer');
        rmdir(installer_path, 's');
    end
    
    opts = compiler.package.InstallerOptions(...
        'ApplicationName', app_name, ...
        'Version', "0.1", ...
        'InstallerName', installer_name, ...
        'RuntimeDelivery', 'web', ...
        'OutputDir', outdir);
    compiler.package.installer(...
        app_full_path, ...
        app_path + "/requiredMCRProducts.txt", ...
        'Options', opts);
end

function cmdout = l_check_output(cmd)
    % Run system command, throws error if command fails.
    % Returns command output
    disp(cmd)
    [status, cmdout] = system(cmd, '-echo');
    if status ~= 0
        error(cmdout)
    end
end
