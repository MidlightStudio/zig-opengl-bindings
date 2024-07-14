const std = @import("std");
const w32 = @import("win32").everything;

const gl = @import("opengl");

var hwnd: w32.HWND = undefined;
var hdc: w32.HDC = undefined;

pub fn wWinMain(
    hInstance: w32.HINSTANCE,
    hPrevInstance: ?w32.HINSTANCE,
    lpCmdLine: [*c]u16,
    nShowCmd: c_int,
) callconv(std.os.windows.WINAPI) c_int {
    _ = hPrevInstance;
    _ = lpCmdLine;
    _ = nShowCmd;

    const windowStyle: w32.WINDOW_STYLE = .{
        .DLGFRAME = 1,
        .BORDER = 1,
        .SYSMENU = 1,
        .GROUP = 1,
    };

    var r: w32.RECT = undefined;
    r.left = 0;
    r.top = 0;
    r.right = 480;
    r.bottom = 360;

    _ = w32.AdjustWindowRect(&r, windowStyle, 0);

    var wc: w32.WNDCLASSEXW = w32.WNDCLASSEXW{
        .style = .{},
        .cbSize = @sizeOf(w32.WNDCLASSEXW),
        .lpfnWndProc = WindowProc,
        .cbClsExtra = 0,
        .cbWndExtra = 0,
        .hInstance = null,
        .hIcon = w32.LoadIconW(hInstance, std.unicode.utf8ToUtf16LeStringLiteral("MAINICON")),
        .hCursor = null,
        .hbrBackground = null,
        .lpszMenuName = null,
        .lpszClassName = std.unicode.utf8ToUtf16LeStringLiteral("EXAMPLE"),
        .hIconSm = null,
    };

    if (w32.RegisterClassExW(&wc) == 0) std.debug.panic("Could not create window class", .{});

    hwnd = w32.CreateWindowExW(
        .{},
        wc.lpszClassName,
        wc.lpszClassName,
        windowStyle,
        w32.CW_USEDEFAULT,
        w32.CW_USEDEFAULT,
        r.right - r.left,
        r.bottom - r.top,
        null,
        null,
        hInstance,
        null,
    ) orelse std.debug.panic("Could not create window", .{});

    var pfd: w32.PIXELFORMATDESCRIPTOR = undefined;
    pfd.nSize = @sizeOf(w32.PIXELFORMATDESCRIPTOR);
    pfd.nVersion = 1;
    pfd.dwFlags = .{
        .DOUBLEBUFFER = 1,
        .DRAW_TO_WINDOW = 1,
        .SUPPORT_OPENGL = 1,
    };
    pfd.iPixelType = .RGBA;
    pfd.cColorBits = 32;

    const pixelFormat = w32.ChoosePixelFormat(w32.GetDC(hwnd), &pfd);
    if (pixelFormat == 0) std.debug.panic("Could not choose pixel format", .{});

    if (w32.SetPixelFormat(w32.GetDC(hwnd), pixelFormat, &pfd) == 0) std.debug.panic("Could not set pixel format", .{});

    const hgl = w32.wglCreateContext(w32.GetDC(hwnd));
    if (hgl == null) std.debug.panic("Could not init open gl", .{});

    if (w32.wglMakeCurrent(w32.GetDC(hwnd), hgl) == 0)
        std.debug.panic("Could not use the open gl context", .{});

    gl.init();

    _ = w32.ShowWindow(hwnd, w32.SW_RESTORE);

    hdc = w32.GetDC(hwnd).?;
    var msg: w32.MSG = undefined;

    while (true) {
        _ = w32.SwapBuffers(hdc);
        while (w32.PeekMessageW(&msg, null, 0, 0, w32.PM_REMOVE) != 0) {
            _ = w32.TranslateMessage(&msg);
            _ = w32.DispatchMessageW(&msg);
        }
    }
}

pub export fn WindowProc(
    procHwnd: w32.HWND,
    uMsg: c_uint,
    wParam: w32.WPARAM,
    lParam: w32.LPARAM,
) callconv(std.os.windows.WINAPI) w32.LRESULT {
    return switch (uMsg) {
        w32.WM_DESTROY => blk: {
            w32.PostQuitMessage(0);
            std.process.exit(0);
            break :blk 0;
        },
        else => w32.DefWindowProcW(procHwnd, uMsg, wParam, lParam),
    };
}
