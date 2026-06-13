using Serilog;
using Wolverine;
using Wolverine.RabbitMQ;
using nem.Notifications.Endpoints;

var builder = WebApplication.CreateBuilder(args);

builder.Host.UseSerilog((ctx, cfg) =>
    cfg.ReadFrom.Configuration(ctx.Configuration)
       .Enrich.FromLogContext()
       .WriteTo.Console());

builder.Services.AddOpenApi();
builder.Services.AddHealthChecks();

builder.Services.AddSingleton<NotificationStore>();

builder.Host.UseWolverine(opts =>
{
    var rabbitMqHost = builder.Configuration.GetValue<string>("RabbitMQ:Host", "localhost")!;
    opts.UseRabbitMq(new Uri($"amqp://guest:guest@{rabbitMqHost}:5672"))
        .AutoProvision();

    opts.PublishAllMessages().ToRabbitExchange("nem.notifications");
});

var app = builder.Build();

app.MapOpenApi();
app.MapHealthChecks("/health");

app.MapNotificationsEndpoints();

app.Run();

public partial class Program { }
