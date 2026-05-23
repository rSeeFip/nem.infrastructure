FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

COPY ["nem.Contracts/", "nem.Contracts/"]
COPY ["nem.Plugins.Sdk/", "nem.Plugins.Sdk/"]
COPY ["nem.infrastructure/nem.Gateway/nem.Gateway.csproj", "nem.infrastructure/nem.Gateway/"]
RUN dotnet restore "nem.infrastructure/nem.Gateway/nem.Gateway.csproj"

COPY ["nem.Contracts/", "nem.Contracts/"]
COPY ["nem.Plugins.Sdk/", "nem.Plugins.Sdk/"]
COPY ["nem.infrastructure/nem.Gateway/", "nem.infrastructure/nem.Gateway/"]
WORKDIR /src/nem.infrastructure/nem.Gateway
RUN dotnet publish "nem.Gateway.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
WORKDIR /app/nem.Gateway

ENV GATEWAY_PORT=8090

COPY --from=build /app/publish ./
# Copy YARP config to /app/ so Program.cs Path.Combine(ContentRootPath, "..", "yarp-gateway.json") resolves correctly
COPY ["nem.infrastructure/yarp-gateway.json", "/app/yarp-gateway.json"]

EXPOSE 8090

ENTRYPOINT ["dotnet", "nem.Gateway.dll"]
