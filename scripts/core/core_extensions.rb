# =========================================
# 00 - Core | Extensões e Utilidades RGSS
# Compatível com Ruby 1.8 (RGSS / RPG Maker XP)
# =========================================
module RMXPCore
  VERSION = '0.1.0'

  module Config
    DEBUG    = true   # defina para false em builds
    LOG_FILE = 'Game.log'
    LOG_MAX  = 512 * 1024 # 512KB (rota logs antigos)
  end

  # Logger simples com rotação básica
  class Logger
    def initialize(path)
      @path = path
      rotate_if_needed
    end

    def rotate_if_needed
      begin
        if File.exist?(@path) && File.size(@path) > Config::LOG_MAX
          ts = Time.now.strftime('%Y%m%d_%H%M%S')
          File.rename(@path, @path + '.' + ts)
        end
      rescue
        # ignore rotação se falhar
      end
    end

    def write(level, msg)
      return unless Config::DEBUG
      line = "[%s] %-5s %s\n" % [timestamp, level, stringify(msg)]
      begin
        f = File.open(@path, 'a')
        f.write(line)
        f.close
      rescue
        # falha de I/O não deve quebrar o jogo
      end
    end

    def info(msg);  write('INFO',  msg); end
    def warn(msg);  write('WARN',  msg); end
    def error(msg); write('ERROR', msg); end

    def stringify(obj)
      begin
        if obj.is_a?(Array)
          obj.collect { |o| stringify(o) }.join(', ')
        else
          obj.to_s
        end
      rescue
        '<uninspectable>'
      end
    end

    def timestamp
      t = Time.now
      "%04d-%02d-%02d %02d:%02d:%02d" % [t.year, t.mon, t.mday, t.hour, t.min, t.sec]
    end
  end

  # Singleton do logger
  def self.logger
    @logger ||= Logger.new(Config::LOG_FILE)
  end

  # Helpers gerais
  module Util
    module_function

    def clamp(v, min, max)
      return min if v < min
      return max if v > max
      v
    end

    def try(obj, method, default_value)
      begin
        obj.send(method)
      rescue
        default_value
      end
    end

    def safe(&block)
      begin
        block.call
      rescue => e
        RMXPCore.logger.error("Exception: #{e} (#{e.class})")
        begin
          bt = e.backtrace || []
          RMXPCore.logger.error(bt.join("\n"))
        rescue
        end
        nil
      end
    end

    # Medição simples de tempo de execução
    def measure(label)
      start = Time.now
      result = nil
      begin
        result = yield
      ensure
        elapsed = (Time.now - start)
        RMXPCore.logger.info("Measure(#{label}): #{(elapsed * 1000).to_i} ms")
      end
      result
    end
  end
end

# Conveniências globais (somente em DEBUG)
if RMXPCore::Config::DEBUG
  module Kernel
    alias :__rpx_old_p :p rescue nil
    def p(*args)
      RMXPCore.logger.info(args)
      begin
        __rpx_old_p(*args) if defined?(__rpx_old_p)
      rescue
      end
      nil
    end
  end
end

# API curta
def log_info(msg);  RMXPCore.logger.info(msg);  end
def log_warn(msg);  RMXPCore.logger.warn(msg);  end
def log_error(msg); RMXPCore.logger.error(msg); end

# Exemplos:
# log_info('Jogo iniciado')
# value = RMXPCore::Util.clamp(120, 0, 100)
# result = RMXPCore::Util.safe { arr.at(99) }
# RMXPCore::Util.measure('cálculo') { heavy_compute() }
