classdef TTLController < handle
    %TTLCONTROLLER Safe serial control of a stateless Arduino TTL adapter.

    properties (SetAccess = private)
        Enabled logical = false
        Port string = ""
        IsHigh logical = false
    end

    properties (Access = private)
        Serial
        HighCommand char = 'a'
        LowCommand char = 'b'
    end

    methods
        function obj = TTLController(syncConfig)
            obj.Enabled = logical(syncConfig.enabled);
            obj.Port = string(syncConfig.port);
            obj.HighCommand = char(syncConfig.highCommand);
            obj.LowCommand = char(syncConfig.lowCommand);
            if ~obj.Enabled
                return
            end

            obj.Serial = serialport(obj.Port, syncConfig.baudRate);
            flush(obj.Serial);
            obj.low();
            pause(syncConfig.initialLowPauseSec);
            obj.low();
        end

        function high(obj)
            if obj.Enabled
                write(obj.Serial, obj.HighCommand, 'char');
            end
            obj.IsHigh = true;
        end

        function low(obj)
            if obj.Enabled && ~isempty(obj.Serial)
                write(obj.Serial, obj.LowCommand, 'char');
            end
            obj.IsHigh = false;
        end

        function pulse(obj, durationSec)
            obj.high();
            WaitSecs(durationSec);
            obj.low();
        end

        function delete(obj)
            % Destructors must never leave the physical output intentionally
            % high, even if presentation or saving raised an exception.
            try
                obj.low();
                if obj.Enabled && ~isempty(obj.Serial)
                    flush(obj.Serial);
                end
            catch
            end
            obj.Serial = [];
        end
    end
end
